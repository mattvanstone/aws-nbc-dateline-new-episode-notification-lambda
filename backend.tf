terraform {
  backend "s3" {
    # Update to match bucket name defined in backend section of main.tf
    bucket = "aws-dateline-lambda-state-bucket"
    key    = "terraform.tfstate"
    # Update to match table name defined in backend section of main.tf
    dynamodb_table = "aws-dateline-lambda-state"
    region         = "us-east-1"
  }
}