terraform {
  backend "s3" {
    profile        = "somoto"
    bucket         = "tf-state-s3"
    dynamodb_table = "tf-state-locks"
    encrypt        = true
    key            = "ecs_service/terraform.tfstate"
    region         = "us-east-1"
  }
}
