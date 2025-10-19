terraform {
  backend "s3" {
    bucket         = "secrets-manager-poc-tfstate-e040b8a3"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    kms_key_id     = "c7001033-7a90-4503-8dd8-7f4e96a69d68"
    dynamodb_table = "terraform-state-lock"
  }
}
