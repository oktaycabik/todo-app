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
  description = "S3 bucket erişimi olan IAM kullanıcı adı"
  type        = string
}

variable "ec2_public_ip" {
  type = string
}

variable "my_public_ip" {
  description = "SSH erişimi için IP adresi"
  type        = string
  default     = "0.0.0.0/32"
} 

