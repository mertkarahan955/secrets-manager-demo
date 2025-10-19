# Secrets Manager PoC

AWS Secrets Manager'ın ECS Fargate üzerinde nasıl kullanılacağını gösteren enterprise-grade güvenlik ile PoC projesi.

## Proje Yapısı

```
├── backend/           # FastAPI uygulaması
│   ├── main.py       # Ana uygulama kodu
│   ├── Dockerfile    # Container image (AMD64 platform)
│   └── requirements.txt
├── terraform/        # Infrastructure as Code
│   ├── main.tf      # VPC, networking
│   ├── ecs.tf       # ECS cluster, service, ECR, Docker build
│   ├── alb.tf       # Application Load Balancer
│   ├── secrets.tf   # Secrets Manager (KMS encrypted)
│   ├── backend-setup.tf # S3 backend, DynamoDB, KMS
│   ├── github-oidc.tf   # GitHub Actions OIDC provider
│   ├── variables.tf # Terraform değişkenleri
│   └── outputs.tf   # Çıktılar
├── .github/workflows/
│   └── deploy.yml   # GitHub Actions CI/CD
├── setup-backend.sh # Backend kurulum (tek seferlik)
├── deploy.sh        # Ana deployment
├── cleanup.sh       # Temizlik
├── .gitignore       # Git ignore (terraform.tfvars dahil)
└── README.md        # Bu dosya
```

## Güvenlik Özellikleri

- **S3 Backend**: Terraform state KMS ile encrypted
- **Secrets Manager**: KMS ile encrypted secrets
- **GitHub OIDC**: Keyless authentication (no AWS keys)
- **IAM**: Minimum required permissions
- **Network**: Security groups ile controlled access
- **Container**: AMD64 platform, non-root user

## Kurulum

### 1. Önkoşullar
```bash
# AWS CLI configured
aws configure list

# Docker running
docker --version

# Terraform installed
terraform --version
```

### 2. Secrets dosyasını hazırla
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars'ı gerçek değerlerle doldur
```

### 3. Backend kurulumu (tek seferlik)
```bash
./setup-backend.sh
```

### 4. Ana deployment
```bash
./deploy.sh
```

## Test

Deployment tamamlandıktan sonra:

```bash
# Health check
curl http://your-alb-url/health

# Ana endpoint
curl http://your-alb-url/

# Test secret
curl http://your-alb-url/secret/test-secret

# API keys secret
curl http://your-alb-url/secret/api-keys
```

## GitHub Actions CI/CD

1. **GitHub Secrets'ı ayarla:**
   - `AWS_ACCESS_KEY_ID`: AWS Access Key ID
   - `AWS_SECRET_ACCESS_KEY`: AWS Secret Access Key
   - `API_KEY`: API key değeri
   - `API_KEY_SECRET`: API secret değeri

2. **Push to main branch** otomatik deploy tetikler

## API Endpoints

- `GET /` - Ana endpoint, mevcut endpoint'leri listeler
- `GET /health` - Health check endpoint
- `GET /secret/{secret_name}` - Secrets Manager'dan secret getir

## Temizlik

```bash
./cleanup.sh
```

## Teknik Detaylar

- **Platform**: ECS Fargate
- **Runtime**: Python 3.11 (FastAPI + Uvicorn)
- **Database**: AWS Secrets Manager
- **Encryption**: KMS (both state and secrets)
- **Networking**: VPC, public subnets, ALB
- **Monitoring**: CloudWatch logs
- **CI/CD**: GitHub Actions with OIDC
