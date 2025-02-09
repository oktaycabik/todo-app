# AWS bölgesini belirtir
provider "aws" {
  region = "eu-central-1"
}

# Frontend için S3 bucket oluşturur - React uygulaması burada host edilecek
resource "aws_s3_bucket" "frontend" {
  bucket = "todo-app-frontend-bucket-oktay"
  lifecycle {
    prevent_destroy = true
    ignore_changes = [tags]
  }
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# S3 bucket'ı statik web sitesi olarak yapılandırır
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  index_document {
    suffix = "index.html"
  }
}

# S3 bucket public access ayarları
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAllPublicAccess"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "${aws_s3_bucket.frontend.arn}",
          "${aws_s3_bucket.frontend.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "AllowIAMUserAccess"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.iam_user_name}"
        }
        Action    = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.frontend.arn}",
          "${aws_s3_bucket.frontend.arn}/*"
        ]
      }
    ]
  })
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "todo-app-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for DynamoDB access
resource "aws_iam_role_policy" "dynamodb_policy" {
  name = "todo-app-dynamodb-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.todo_table.arn
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "todo-app-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Amazon Linux 2 AMI'yi al
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Backend için EC2 sunucusu oluşturur
resource "aws_instance" "backend" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  key_name      = "todo-app-key-v3"  # Manuel oluşturduğunuz key pair'in adı
  vpc_security_group_ids = [aws_security_group.backend.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              curl -sL https://rpm.nodesource.com/setup_18.x | bash -
              yum install -y nodejs npm
              npm install -g pm2
              mkdir -p /home/ec2-user/app
              chown -R ec2-user:ec2-user /home/ec2-user/app
              chmod 700 /home/ec2-user/.ssh
              chmod 600 /home/ec2-user/.ssh/authorized_keys
              EOF

  tags = {
    Name = "todo-app-backend"
  }
}

# EC2'nin public IP'sini output olarak alma
output "ec2_public_ip" {
  value       = aws_instance.backend.public_ip
  description = "EC2 instance public IP address"
  sensitive   = false
}

# EC2 instance ID'sini output olarak alma
output "instance_id" {
  value       = aws_instance.backend.id
  description = "EC2 instance ID"
  sensitive   = false
}

# CloudFront dağıtımı oluşturur - Frontend için CDN hizmeti
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }
  enabled = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "s3-oac"
  description                       = "OAC Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_caller_identity" "current" {}

resource "aws_security_group" "backend" {
  name = "todo-app-backend-sg-v3"
  lifecycle {
    create_before_destroy = true
  }

  # API için 3001 portunu açar
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH bağlantısı için 22 portunu açar
  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}", "0.0.0.0/0"]
  }

  # Dışarı giden tüm trafiğe izin verir
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DynamoDB Table
resource "aws_dynamodb_table" "todo_table" {
  name           = "Todos"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name        = "todo-items"
    Environment = var.environment
  }
} 