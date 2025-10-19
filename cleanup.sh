#!/bin/bash

echo "🧹 Secrets Manager PoC Cleanup"
echo ""
echo "⚠️  Bu işlem TÜM AWS kaynaklarını silecek:"
echo "   - ECS Fargate cluster ve service"
echo "   - Application Load Balancer"
echo "   - VPC ve networking"
echo "   - Secrets Manager secrets"
echo "   - S3 bucket (Terraform state)"
echo "   - ECR repository ve images"
echo "   - IAM roles ve policies"
echo ""
read -p "Devam etmek istediğinizden emin misiniz? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ İşlem iptal edildi."
    exit 1
fi

echo "🗑️  Kaynaklar siliniyor..."

cd terraform

# ECR images'ları temizle (eğer varsa)
echo "🐳 ECR images temizleniyor..."
aws ecr delete-repository --repository-name secrets-manager-poc --force --region eu-west-1 2>/dev/null || echo "ECR repository zaten silinmiş"

# Terraform destroy
terraform destroy -auto-approve

echo "✅ Tüm kaynaklar silindi!"
echo "💡 S3 bucket versioning enabled olduğu için eski state dosyaları kalabilir."
