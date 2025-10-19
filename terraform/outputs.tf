output "terraform_state_bucket_name" {
  description = "Terraform state S3 bucket name"
  value       = aws_s3_bucket.terraform_state.bucket
}

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

output "test_endpoints" {
  description = "Test endpoints"
  value = {
    health_check = "http://${aws_lb.app.dns_name}/health"
    root         = "http://${aws_lb.app.dns_name}/"
    test_secret  = "http://${aws_lb.app.dns_name}/secret/test-secret"
    api_keys     = "http://${aws_lb.app.dns_name}/secret/api-keys"
  }
}
