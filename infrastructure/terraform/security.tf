# EC2 instance için güvenlik grubu
resource "aws_security_group" "backend" {
  name = "todo-app-backend-sg"

  # API için 3001 portunu açar
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH bağlantısı için 22 portunu açar
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Dışarı giden tüm trafiğe izin verir
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
} 