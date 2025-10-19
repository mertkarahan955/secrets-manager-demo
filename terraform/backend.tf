terraform {
  backend "s3" {
    bucket         = "secrets-manager-poc-tfstate-3e002c35"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key"
    dynamodb_table = "terraform-state-lock"
  }
}
