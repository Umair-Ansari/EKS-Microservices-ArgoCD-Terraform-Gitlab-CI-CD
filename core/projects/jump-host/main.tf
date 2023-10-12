data "aws_ami" "aws_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"] # Amazon Linux 2
  }
}

resource "aws_instance" "jump-host" {
  ami           = data.aws_ami.aws_linux.id
  instance_type = "t3.nano"
  subnet_id     = var.subnet_id

  key_name      = var.ssh-key
  tags = {
    Name = "jump-host"
  }

  associate_public_ip_address = true

  vpc_security_group_ids = [var.ssh-sg]
}