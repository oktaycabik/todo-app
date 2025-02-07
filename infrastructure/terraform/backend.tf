terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0, < 5.0.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-todo-app-oktay"
    key    = "terraform.tfstate"
    region = "eu-central-1"
  }
} 