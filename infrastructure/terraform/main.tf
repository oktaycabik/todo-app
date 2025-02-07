# AWS bölgesini belirtir
provider "aws" {
  region = "eu-central-1"
}

# Frontend için S3 bucket oluşturur - React uygulaması burada host edilecek
resource "aws_s3_bucket" "frontend" {
  bucket = "todo-app-frontend-bucket-oktay"
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
        Sid       = "AllowPublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.frontend.arn}",
          "${aws_s3_bucket.frontend.arn}/*"
        ]
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

# DynamoDB tablosu
resource "aws_dynamodb_table" "todos" {
  name           = "Todos-v2"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

# EC2 için SSH key pair oluşturur
resource "aws_key_pair" "deployer" {
  key_name   = "todo-app-key-v2"
  public_key = tls_private_key.pk.public_key_openssh
  lifecycle {
    create_before_destroy = true
  }
}

# SSH key pair oluşturma
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Private key'i local dosyaya kaydetme
resource "local_file" "private_key" {
  content  = tls_private_key.pk.private_key_pem
  filename = "todo-app-key.pem"
}

# Backend için EC2 sunucusu oluşturur - Node.js API burada çalışacak
resource "aws_instance" "backend" {
  ami           = "ami-0669b163befffbdfc"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.backend.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nodejs npm
              npm install -g pm2
              mkdir -p /home/ec2-user/app
              chown -R ec2-user:ec2-user /home/ec2-user/app
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

# Private key'i output olarak alma
output "private_key" {
  value       = tls_private_key.pk.private_key_pem
  description = "Generated SSH private key for EC2 access"
  sensitive   = true
}

# CloudFront dağıtımı oluşturur - Frontend için CDN hizmeti
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3Origin"
  }
  enabled = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
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
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

data "aws_caller_identity" "current" {} 