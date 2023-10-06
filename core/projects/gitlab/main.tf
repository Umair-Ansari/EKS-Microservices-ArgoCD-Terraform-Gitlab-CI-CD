terraform {
    backend "s3" {
      bucket                  = "your_s3_bucket"
      dynamodb_table          = "terraform-lock"
      key                     = "gitlab"
      region                  = "me-central-1"
    }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}


data "aws_ami" "ubuntu-ami" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical owner ID for Ubuntu AMIs

  filter {
    name   = "name"
    values = ["ubuntu/images/*ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "gitlab" {
  ami           = data.aws_ami.ubuntu-ami.id
  instance_type = "t3.large"
  subnet_id     = var.subnet_id

  key_name      = var.ssh-key
  tags = {
    Name = "gitlab"
  }
}