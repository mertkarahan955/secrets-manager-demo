from fastapi import FastAPI, HTTPException
import boto3
from botocore.exceptions import ClientError
import json
import os

app = FastAPI(title="Secrets Manager PoC")

secrets_client = boto3.client('secretsmanager', region_name=os.getenv('AWS_REGION', 'eu-west-1'))

@app.get("/")
async def root():
    return {
        "message": "Secrets Manager PoC is working as expected.",
        "endpoints": {
            "/health": "Health check endpoint",
            "/secret/{secret_name}": "Get secret by name from AWS Secrets Manager"
        }
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@app.get("/secret/{secret_name}")
async def get_secret(secret_name: str):
    """
    Get the specified secret from Secrets Manager
    """
    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        
        # Secret can be string or binary
        if 'SecretString' in response:
            secret = response['SecretString']
            # Check if it's JSON format
            try:
                secret_dict = json.loads(secret)
                return {
                    "secret_name": secret_name,
                    "secret_value": secret_dict,
                    "version_id": response.get('VersionId'),
                    "created_date": response.get('CreatedDate').isoformat() if response.get('CreatedDate') else None
                }
            except json.JSONDecodeError:
                # Plain text secret
                return {
                    "secret_name": secret_name,
                    "secret_value": secret,
                    "version_id": response.get('VersionId'),
                    "created_date": response.get('CreatedDate').isoformat() if response.get('CreatedDate') else None
                }
        else:
            # Binary secret
            return {
                "secret_name": secret_name,
                "secret_value": "Binary secret (base64 encoded)",
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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)