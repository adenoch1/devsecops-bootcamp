terraform {
  backend "s3" {
    bucket               = "devsecops-testing-tfstate-enoch-2026"
    key                  = "platform/terraform.tfstate"
    workspace_key_prefix = "environments"
    region               = "ca-central-1"
    dynamodb_table       = "devsecops-testing-tflocks"
    encrypt              = true
  }
}
