#!/bin/bash

set -e

echo "🏗️  Setting up Terraform backend infrastructure with AWS CLI..."

REGION="eu-west-1"
PROJECT_NAME="secrets-manager-poc"
BUCKET_SUFFIX=$(openssl rand -hex 4)
BUCKET_NAME="${PROJECT_NAME}-tfstate-${BUCKET_SUFFIX}"

# Check if terraform.tfvars exists
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo "❌ terraform/terraform.tfvars not found!"
    echo "📝 Copy terraform/terraform.tfvars.example to terraform/terraform.tfvars and fill with real values"
    exit 1
fi

echo "📦 Creating S3 bucket: $BUCKET_NAME"

# 1. Create KMS key for encryption
echo "🔐 Creating KMS key..."
KMS_KEY_ID=$(aws kms create-key \
    --description "KMS key for Terraform state encryption" \
    --region $REGION \
    --query 'KeyMetadata.KeyId' \
    --output text)

# 2. Create KMS alias
aws kms create-alias \
    --alias-name alias/terraform-state-key \
    --target-key-id $KMS_KEY_ID \
    --region $REGION

# 3. Create S3 bucket
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION

# 4. Enable versioning
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled

# 5. Enable encryption
aws s3api put-bucket-encryption \
    --bucket $BUCKET_NAME \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "aws:kms",
                "KMSMasterKeyID": "alias/terraform-state-key"
            }
        }]
    }'

# 6. Block public access
aws s3api put-public-access-block \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# 7. Create DynamoDB table for locking
echo "🔒 Creating DynamoDB table for state locking..."
aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION

# 8. Update backend configuration
echo "🔧 Updating backend configuration..."
cat > terraform/backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "terraform.tfstate"
    region         = "$REGION"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key"
    dynamodb_table = "terraform-state-lock"
  }
}
EOF

echo "✅ Backend infrastructure created!"
echo "📦 S3 Bucket: $BUCKET_NAME"
echo "🔐 KMS Key: $KMS_KEY_ID"
echo "🔒 DynamoDB Table: terraform-state-lock"
echo ""
echo "🚀 Now run: ./deploy.sh"
