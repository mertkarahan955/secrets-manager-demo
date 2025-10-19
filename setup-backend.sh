#!/bin/bash

set -e

echo "🏗️  Setting up Terraform backend infrastructure..."

cd terraform

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars not found!"
    echo "📝 Copy terraform.tfvars.example to terraform.tfvars and fill with real values"
    exit 1
fi

# First, create backend infrastructure without backend config
terraform init
terraform apply -target=aws_s3_bucket.terraform_state -target=aws_dynamodb_table.terraform_state_lock -target=aws_kms_key.terraform_state -target=aws_kms_alias.terraform_state -target=random_id.bucket_suffix -auto-approve

# Get bucket name
BUCKET_NAME=$(terraform output -raw terraform_state_bucket_name)

echo "✅ Backend infrastructure created!"
echo "📦 S3 Bucket: $BUCKET_NAME"
echo ""
echo "🔄 Configuring backend..."

# Configure backend
terraform init -backend-config="bucket=$BUCKET_NAME" -backend-config="key=terraform.tfstate" -backend-config="region=eu-west-1" -backend-config="encrypt=true" -backend-config="kms_key_id=alias/terraform-state-key" -backend-config="dynamodb_table=terraform-state-lock"

echo "✅ Backend configured!"
echo "🚀 Now run: ./deploy.sh"
