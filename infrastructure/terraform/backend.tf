terraform {
  backend "s3" {
    bucket = "terraform-state-todo-app"
    key    = "terraform.tfstate"
    region = "eu-central-1"
  }
} 