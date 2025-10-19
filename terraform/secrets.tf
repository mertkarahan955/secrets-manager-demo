# KMS Key for Secrets Manager
resource "aws_kms_key" "secrets_manager" {
  description             = "KMS key for Secrets Manager encryption"
  deletion_window_in_days = 7

  tags = {
    Name = "${var.project_name}-secrets-manager-key"
  }
}

resource "aws_kms_alias" "secrets_manager" {
  name          = "alias/secrets-manager-key"
  target_key_id = aws_kms_key.secrets_manager.key_id
}

# Test Secret (KMS encrypted)
resource "aws_secretsmanager_secret" "test_secret" {
  name                    = "test-secret"
  description             = "Test secret for PoC demonstration"
  kms_key_id              = aws_kms_key.secrets_manager.arn
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "test_secret" {
  secret_id = aws_secretsmanager_secret.test_secret.id
  secret_string = jsonencode({
    username = "testuser"
    password = "testpass123"
    database = "mydb"
    api_key  = "abc123xyz789"
  })
}

# API Keys Secret (KMS encrypted, from variables)
resource "aws_secretsmanager_secret" "api_keys" {
  name                    = "api-keys"
  description             = "API keys for external services"
  kms_key_id              = aws_kms_key.secrets_manager.arn
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    api_key        = var.api_key
    api_key_secret = var.api_key_secret
    service_name   = "external-service"
  })
}
