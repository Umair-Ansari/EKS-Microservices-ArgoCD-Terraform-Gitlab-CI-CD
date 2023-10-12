###################  IAM Gitlab-Server Role  ###################

resource "aws_iam_role" "gitlab_server" {
  name               = "gitlab-role"
  assume_role_policy = file("${path.module}/assumerolepolicy.json")
}

resource "aws_iam_policy" "gitlab_policy" {
  name        = "gitlab-policy"
  description = "Gitlab policy"
  policy      = file("${path.module}/gitlab_policy.json")
}

resource "aws_iam_policy_attachment" "gitlab-attach" {
  name       = "test-attachment"
  roles      = [aws_iam_role.gitlab_server.name]
  policy_arn = aws_iam_policy.gitlab_policy.arn
}

resource "aws_iam_instance_profile" "gitlab_profile" {
  name = "gitlab_profile"
  role = aws_iam_role.gitlab_server.name
}

###################  EC2  ###################
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

resource "aws_security_group" "gitlab-ec2" {
  name        = "allow_gitlab"
  description = "Allow TLS inbound traffic"
  vpc_id      = var.vpc.id

  ingress {
    description      = "gitlab-alb-allow"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    security_groups  = [aws_security_group.gitlab-alb.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "gitlab-alb"
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
  iam_instance_profile = aws_iam_instance_profile.gitlab_profile.name
  user_data = file("${path.module}/startup.sh")
  vpc_security_group_ids = [aws_security_group.gitlab-ec2.id]
}

################# ALB ###############

resource "aws_security_group" "gitlab-alb" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = var.vpc.id

  ingress {
    description      = "gitlab-alb"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "gitlab-alb"
  }
}

resource "aws_lb" "gitlab" {
  name               = "gitlab-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.gitlab-alb.id]
  subnets            = var.l1_subnets

  tags = {
    Environment = "gitlab-alb"
  }
}



resource "aws_lb_target_group" "gitlab-tg" {
  name        = "gitlab-tg"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc.id
}

resource "aws_lb_target_group_attachment" "gitlab" {
  target_group_arn = aws_lb_target_group.gitlab-tg.arn
  target_id      = aws_instance.gitlab.id
  port             = 80
}


resource "aws_lb_listener" "gitlab" {
  load_balancer_arn = aws_lb.gitlab.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitlab-tg.arn
  }
}

#resource "aws_lb_listener" "gitlab" {
#  load_balancer_arn = aws_lb.gitlab.arn
#  port              = "443"
#  protocol          = "HTTPs"
#  ssl_policy        = "ELBSecurityPolicy-2016-08"
#  certificate_arn   = "arn:aws:iam::id:server-certificate/test_cert_rhftfyfyy

#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.gitlab-tg.arn
#  }
#}

################ R53 ################
data "aws_route53_zone" "r53" {
  name = "muhammadumair.com"
}


resource "aws_route53_record" "gitlab-ci" {
  zone_id = data.aws_route53_zone.r53.zone_id
  name    = "gitlab-ci.muhammadumair.com"
  type    = "CNAME"
  ttl     = "60"
  records = [aws_lb.gitlab.dns_name]  # Replace with your actual IP address
}


