#!/bin/bash

set -e

echo "🚀 Secrets Manager PoC Deployment"

cd terraform

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars not found!"
    echo "📝 Copy terraform.tfvars.example to terraform.tfvars and fill with real values"
    exit 1
fi

# Terraform workflow (backend already configured)
terraform plan
terraform apply -auto-approve

echo "✅ Deployment completed!"
echo ""
echo "🌐 Test endpoints:"
terraform output test_endpoints
