# Secrets Manager PoC

A PoC project demonstrating how to use AWS Secrets Manager on ECS Fargate with enterprise-grade security.

## Project Structure

```
├── backend/           # FastAPI application
│   ├── main.py       # Main application code
│   ├── Dockerfile    # Container image (AMD64 platform)
│   └── requirements.txt
├── terraform/        # Infrastructure as Code
│   ├── main.tf      # VPC, networking
│   ├── ecs.tf       # ECS cluster, service, ECR, Docker build
│   ├── alb.tf       # Application Load Balancer
│   ├── secrets.tf   # Secrets Manager (KMS encrypted)
│   ├── backend-setup.tf # S3 backend, DynamoDB, KMS
│   ├── github-oidc.tf   # GitHub Actions OIDC provider
│   ├── variables.tf # Terraform variables
│   └── outputs.tf   # Outputs
├── .github/workflows/
│   └── deploy.yml   # GitHub Actions CI/CD
├── setup-backend.sh # Backend setup (one-time)
├── deploy.sh        # Main deployment
├── cleanup.sh       # Application cleanup (backend preserved)
├── cleanup-backend.sh # Full cleanup (IRREVERSIBLE)
├── .gitignore       # Git ignore (terraform.tfvars included)
└── README.md        # This file
```

## Security Features

- **S3 Backend**: Terraform state encrypted with KMS
- **Secrets Manager**: KMS encrypted secrets
- **GitHub OIDC**: Keyless authentication (no AWS keys)
- **IAM**: Minimum required permissions
- **Network**: Controlled access with security groups
- **Container**: AMD64 platform, non-root user

## Setup

### 1. Prerequisites
```bash
# AWS CLI configured
aws configure list

# Docker running
docker --version

# Terraform installed
terraform --version
```

### 2. Prepare secrets file
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Fill terraform.tfvars with real values
```

### 3. Backend setup (one-time)
```bash
./setup-backend.sh
```

### 4. Main deployment
```bash
./deploy.sh
```

## Testing

After deployment completes:

```bash
# Health check
curl http://your-alb-url/health

# Main endpoint
curl http://your-alb-url/

# Demo test secret
curl http://your-alb-url/secret/demo-test-secret

# API keys secret
curl http://your-alb-url/secret/secret-api-keys
```

## GitHub Actions CI/CD

1. **Set up GitHub Secrets:**
   - `AWS_ACCESS_KEY_ID`: AWS Access Key ID
   - `AWS_SECRET_ACCESS_KEY`: AWS Secret Access Key
   - `API_KEY`: API key value
   - `API_KEY_SECRET`: API secret value

2. **Push to main branch** triggers automatic deployment

## API Endpoints

- `GET /` - Main endpoint, lists available endpoints
- `GET /health` - Health check endpoint
- `GET /secret/{secret_name}` - Get secret from Secrets Manager

## Cost Management

### Application Resources Cleanup (Safe)
```bash
./cleanup.sh
```
**Deletes:**
- ECS Fargate cluster and service
- Application Load Balancer
- VPC and networking
- Secrets Manager secrets
- ECR repository and images
- IAM roles and policies

**Preserves:**
- S3 bucket (Terraform state)
- DynamoDB (state lock)
- KMS key (backend encryption)

### Re-deployment
Since backend is preserved:
```bash
# Manual deployment
./deploy.sh

# Or push to GitHub (automatic)
git push origin main
```

### Full Cleanup (WARNING - IRREVERSIBLE)
```bash
./cleanup-backend.sh
```
**Deletes all resources, tfstate is lost!**

## Technical Details

- **Platform**: ECS Fargate
- **Runtime**: Python 3.11 (FastAPI + Uvicorn)
- **Database**: AWS Secrets Manager
- **Encryption**: KMS (both state and secrets)
- **Networking**: VPC, public subnets, ALB
- **Monitoring**: CloudWatch logs
- **CI/CD**: GitHub Actions with automatic image updates
- **State Management**: S3 backend with DynamoDB locking
