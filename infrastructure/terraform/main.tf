# AWS bölgesini belirtir
provider "aws" {
  region = "eu-central-1"
}

# Frontend için S3 bucket oluşturur - React uygulaması burada host edilecek
resource "aws_s3_bucket" "frontend" {
  bucket = "todo-app-frontend-bucket"
}

# S3 bucket'ı statik web sitesi olarak yapılandırır
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  index_document {
    suffix = "index.html"
  }
}

# DynamoDB tablosu oluşturur - Todo'lar burada saklanacak
resource "aws_dynamodb_table" "todos" {
  name           = "Todos"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

# EC2 için SSH key pair oluşturur
resource "aws_key_pair" "deployer" {
  key_name   = "todo-app-key"
  public_key = tls_private_key.pk.public_key_openssh
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
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.backend.id]
  tags = {
    Name = "todo-app-backend"
  }
}

# EC2'nin public IP'sini output olarak alma
output "ec2_public_ip" {
  value = aws_instance.backend.public_ip
}

# Private key'i output olarak alma
output "private_key" {
  value     = tls_private_key.pk.private_key_pem
  sensitive = true
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