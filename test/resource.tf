resource "aws_key_pair" "install_test_key" {
  key_name   = "InstallTestKeyPair"
  public_key = file(var.public_key)
}

resource "aws_instance" "install_test_instance" {
  count = length(var.distros)

  ami           = var.amis[count.index]
  instance_type = var.instance
  key_name      = aws_key_pair.install_test_key.key_name

  vpc_security_group_ids = [
    aws_security_group.install_sg.id
  ]

  connection {
    type        = "ssh"
    host        = self.public_ip
    private_key = file(var.private_key)
    user        = var.ami_users[count.index]
  }

  tags = {
    Name         = var.distros[count.index]
    environment  = var.environment_tag
    owning_team  = var.owning_team_tag
    product      = var.product_tag
  }
}

resource "aws_security_group" "install_sg" {
  name        = "install-security-group"
  description = "Security group that allows SSH traffic from internet"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name         = "install-security-group"
    environment  = var.environment_tag
    owning_team  = var.owning_team_tag
    product      = var.product_tag
  }
}
