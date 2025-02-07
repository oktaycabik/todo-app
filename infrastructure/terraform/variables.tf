variable "aws_region" {
  default = "eu-central-1"
}

variable "app_name" {
  default = "todo-app"
}

variable "environment" {
  default = "production"
}

variable "iam_user_name" {
  description = "The IAM user name that will have access to the S3 bucket"
  type        = string
} 