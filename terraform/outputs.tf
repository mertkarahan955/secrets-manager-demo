output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.app.dns_name
}

output "alb_url" {
  description = "Application Load Balancer URL"
  value       = "http://${aws_lb.app.dns_name}"
}

output "cache_endpoint" {
  description = "ElastiCache Valkey endpoint"
  value       = aws_elasticache_serverless_cache.valkey.endpoint[0].address
}

output "cache_port" {
  description = "ElastiCache Valkey port"
  value       = aws_elasticache_serverless_cache.valkey.endpoint[0].port
}

output "test_endpoints" {
  description = "Test endpoints"
  value = {
    health_check  = "http://${aws_lb.app.dns_name}/health"
    root          = "http://${aws_lb.app.dns_name}/"
    test_secret   = "http://${aws_lb.app.dns_name}/secret/demo-test-secret"
    api_keys      = "http://${aws_lb.app.dns_name}/secret/secret-api-keys"
    cached_secret = "http://${aws_lb.app.dns_name}/secret/demo-test-secret/cached"
  }
}
