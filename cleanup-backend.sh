#!/bin/bash

echo "🧹 Backend Infrastructure Cleanup"
echo ""
echo "⚠️  Bu işlem backend infrastructure'ı silecek:"
echo "   - S3 bucket (Terraform state)"
echo "   - DynamoDB table (state locking)"
echo "   - KMS key ve alias"
echo ""
echo "❗ Bu işlem GERİ ALINAMAZ ve tüm Terraform state'i kaybolur!"
echo ""
read -p "Devam etmek istediğinizden emin misiniz? (DELETE/no): " confirm

if [ "$confirm" != "DELETE" ]; then
    echo "❌ İşlem iptal edildi."
    exit 1
fi

REGION="eu-west-1"

echo "🗑️  Backend infrastructure siliniyor..."

# Get bucket name from backend.tf
BUCKET_NAME=$(grep 'bucket.*=' terraform/backend.tf | sed 's/.*= *"\([^"]*\)".*/\1/')

if [ -n "$BUCKET_NAME" ]; then
    echo "🗑️  S3 bucket siliniyor: $BUCKET_NAME"
    # Empty bucket first
    aws s3 rm s3://$BUCKET_NAME --recursive 2>/dev/null || true
    # Delete bucket
    aws s3api delete-bucket --bucket $BUCKET_NAME --region $REGION 2>/dev/null || true
fi

# Delete DynamoDB table
echo "🗑️  DynamoDB table siliniyor..."
aws dynamodb delete-table --table-name terraform-state-lock --region $REGION 2>/dev/null || true

# Delete KMS alias and key
echo "🗑️  KMS alias siliniyor..."
aws kms delete-alias --alias-name alias/terraform-state-key --region $REGION 2>/dev/null || true

# Get KMS key ID and schedule deletion
KMS_KEY_ID=$(aws kms list-keys --region $REGION --query 'Keys[?KeyId!=`alias/terraform-state-key`].KeyId' --output text 2>/dev/null | head -1)
if [ -n "$KMS_KEY_ID" ]; then
    echo "🗑️  KMS key siliniyor..."
    aws kms schedule-key-deletion --key-id $KMS_KEY_ID --pending-window-in-days 7 --region $REGION 2>/dev/null || true
fi

echo "✅ Backend infrastructure silindi!"
echo "💡 KMS key 7 gün sonra tamamen silinecek."
