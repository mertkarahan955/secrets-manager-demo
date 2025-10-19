#!/bin/bash

echo "🧹 Secrets Manager PoC Cleanup"
echo ""
echo "⚠️  This process will delete all resources:"
echo "   - ECS Fargate cluster and service"
echo "   - Application Load Balancer"
echo "   - VPC and networking"
echo "   - Secrets Manager secrets"
echo "   - ECR repository and images"
echo "   - IAM roles and policies"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Operation canceled."
    exit 1
fi

echo "🗑️  Deleting resources..."

cd terraform

echo "🐳 Deleting ECR images..."
aws ecr delete-repository --repository-name secrets-manager-poc --force --region eu-west-1 2>/dev/null || echo "ECR repository already deleted"

# Terraform destroy
terraform destroy -auto-approve

echo "✅ Tüm kaynaklar silindi!"
