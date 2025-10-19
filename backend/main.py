from fastapi import FastAPI, HTTPException
import boto3
from botocore.exceptions import ClientError
import valkey
import json
import os
import time

app = FastAPI(title="Secrets Manager PoC with ElastiCache")

# Create Secrets Manager client
secrets_client = boto3.client('secretsmanager', region_name=os.getenv('AWS_REGION', 'eu-west-1'))

# Create Valkey client
try:
    valkey_client = valkey.Valkey(
        host=os.getenv('CACHE_ENDPOINT', 'localhost'),
        port=int(os.getenv('CACHE_PORT', 6379)),
        ssl=True,
        ssl_cert_reqs=None,
        decode_responses=True,
        socket_connect_timeout=5,
        socket_timeout=5
    )
    # Test connection
    valkey_client.ping()
    cache_available = True
except Exception as e:
    print(f"Cache connection failed: {e}")
    valkey_client = None
    cache_available = False

@app.get("/")
async def root():
    return {
        "message": "Secrets Manager PoC with ElastiCache is running",
        "endpoints": {
            "/health": "Health check endpoint",
            "/secret/{secret_name}": "Get secret (with cache)",
            "/secret/{secret_name}/cached": "Get secret from cache only",
            "/cache/keys": "List all cached keys",
            "/cache/{key}": "Delete cached key"
        }
    }

@app.get("/health")
async def health_check():
    cache_status = "disconnected"
    if cache_available and valkey_client:
        try:
            valkey_client.ping()
            cache_status = "connected"
        except:
            cache_status = "disconnected"
    
    return {
        "status": "healthy",
        "cache_status": cache_status,
        "cache_endpoint": f"{os.getenv('CACHE_ENDPOINT', 'localhost')}:{os.getenv('CACHE_PORT', 6379)}"
    }

@app.get("/secret/{secret_name}")
async def get_secret(secret_name: str):
    """Get secret with caching (cache-first strategy)"""
    start_time = time.time()
    
    # Check cache first (if available)
    if cache_available and redis_client:
        try:
            cached_value = redis_client.get(f"secret:{secret_name}")
            if cached_value:
                cache_time = time.time() - start_time
                return {
                    "secret_name": secret_name,
                    "secret_value": json.loads(cached_value),
                    "source": "cache",
                    "response_time_ms": round(cache_time * 1000, 2)
                }
        except Exception as e:
            print(f"Cache read error: {e}")
    
    # If not in cache or cache unavailable, get from Secrets Manager
    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        
        if 'SecretString' in response:
            secret = response['SecretString']
            try:
                secret_dict = json.loads(secret)
                
                # Cache the result (TTL: 5 minutes) if cache is available
                if cache_available and redis_client:
                    try:
                        redis_client.setex(f"secret:{secret_name}", 300, json.dumps(secret_dict))
                    except Exception as e:
                        print(f"Cache write error: {e}")
                
                total_time = time.time() - start_time
                return {
                    "secret_name": secret_name,
                    "secret_value": secret_dict,
                    "source": "secrets_manager",
                    "response_time_ms": round(total_time * 1000, 2),
                    "version_id": response.get('VersionId'),
                    "created_date": response.get('CreatedDate').isoformat() if response.get('CreatedDate') else None
                }
            except json.JSONDecodeError:
                # Plain text secret
                if cache_available and redis_client:
                    try:
                        redis_client.setex(f"secret:{secret_name}", 300, secret)
                    except Exception as e:
                        print(f"Cache write error: {e}")
                
                total_time = time.time() - start_time
                return {
                    "secret_name": secret_name,
                    "secret_value": secret,
                    "source": "secrets_manager",
                    "response_time_ms": round(total_time * 1000, 2)
                }
        else:
            return {
                "secret_name": secret_name,
                "secret_value": "Binary secret (base64 encoded)",
                "source": "secrets_manager",
                "version_id": response.get('VersionId')
            }
            
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'ResourceNotFoundException':
            raise HTTPException(status_code=404, detail=f"Secret '{secret_name}' not found")
        elif error_code == 'AccessDeniedException':
            raise HTTPException(status_code=403, detail="Access denied to this secret")
        elif error_code == 'InvalidRequestException':
            raise HTTPException(status_code=400, detail="Invalid request")
        else:
            raise HTTPException(status_code=500, detail=f"An error occurred: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

@app.get("/secret/{secret_name}/cached")
async def get_cached_secret(secret_name: str):
    """Get secret from cache only"""
    if not cache_available or not redis_client:
        raise HTTPException(status_code=503, detail="Cache is not available")
    
    start_time = time.time()
    
    try:
        cached_value = redis_client.get(f"secret:{secret_name}")
        if not cached_value:
            raise HTTPException(status_code=404, detail=f"Secret '{secret_name}' not found in cache")
        
        cache_time = time.time() - start_time
        return {
            "secret_name": secret_name,
            "secret_value": json.loads(cached_value),
            "source": "cache",
            "response_time_ms": round(cache_time * 1000, 2)
        }
    except redis.RedisError as e:
        raise HTTPException(status_code=503, detail=f"Cache error: {str(e)}")

@app.get("/cache/keys")
async def list_cached_keys():
    """List all cached secret keys"""
    if not cache_available or not redis_client:
        raise HTTPException(status_code=503, detail="Cache is not available")
    
    try:
        keys = redis_client.keys("secret:*")
        return {
            "cached_keys": [key.replace("secret:", "") for key in keys],
            "total_count": len(keys)
        }
    except redis.RedisError as e:
        raise HTTPException(status_code=503, detail=f"Cache error: {str(e)}")

@app.delete("/cache/{key}")
async def delete_cached_key(key: str):
    """Delete a key from cache"""
    if not cache_available or not redis_client:
        raise HTTPException(status_code=503, detail="Cache is not available")
    
    try:
        deleted = redis_client.delete(f"secret:{key}")
        if deleted:
            return {"message": f"Key '{key}' deleted from cache"}
        else:
            raise HTTPException(status_code=404, detail=f"Key '{key}' not found in cache")
    except redis.RedisError as e:
        raise HTTPException(status_code=503, detail=f"Cache error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)