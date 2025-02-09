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

variable "my_public_ip" {
  description = "SSH erişimi için IP adresi"
  type        = string
  default     = "0.0.0.0/32"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
} 