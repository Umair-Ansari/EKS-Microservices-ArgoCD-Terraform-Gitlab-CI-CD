
terraform {
    backend "s3" {
      bucket                  = "s3_bucket_name"
      dynamodb_table          = "terraform-lock-core-infra"
      key                     = "core-infra"
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

provider "aws" {
  region  = var.aws_region
}

########## VPC ##########
resource "aws_vpc" "vpc" {
  cidr_block       = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = var.project
  }
}


########## SUBNETS ##########
resource "aws_subnet" "subnets" {
  count = var.subnet_count

  cidr_block = cidrsubnet(var.vpc_cidr, 4, count.index)
  vpc_id     = aws_vpc.vpc.id

  availability_zone = count.index < 4 ? var.availability_zones[0] : count.index < 8 ? var.availability_zones[1] : var.availability_zones[2]
  tags = {
    Name = var.subnets_tags[count.index]
  }
}


########## Internet Gateway ##########
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "igw"
  }
}


########## Route Tables ##########
resource "aws_route_table" "public_rtb" {

  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-public-rtb"
  }
}

resource "aws_route_table" "l2_private_rtb" {
  count = length(var.l2_route_table_tags)
  vpc_id = aws_vpc.vpc.id
   route {
     cidr_block = "0.0.0.0/0"
     gateway_id = count.index <= 1 ? aws_nat_gateway.nat_gw[0].id : count.index <= 3 ? aws_nat_gateway.nat_gw[1].id : aws_nat_gateway.nat_gw[2].id
   }
  tags = {
    Name = "${var.project}-private-rtb-${var.l2_route_table_tags[count.index]}"
  }
}
resource "aws_route_table" "l3_private_rtb" {
  count = length(var.l3_route_table_tags)
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project}-private-rtb-${var.l3_route_table_tags[count.index]}"
  }
}

########## Elastic IPs ##########
resource "aws_eip" "nat" {
  count =  length(var.availability_zones)
}

########## NAT Gateways ##########
resource "aws_nat_gateway" "nat_gw" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = count.index == 1 ? aws_subnet.subnets[0].id : count.index == 2 ? aws_subnet.subnets[4].id : aws_subnet.subnets[8].id

  tags = {
    Name = "${var.project}-nat-${substr(var.availability_zones[count.index], 11, 2)}"
  }

  depends_on = [aws_internet_gateway.igw]
}

########## Gateway Endpoint s3 ##########
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = aws_route_table.l2_private_rtb[*].id
  tags = {
    Name = "gw-s3"
  }
}



########## Gateway Endpoint DynamoDB ##########
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = aws_route_table.l2_private_rtb[*].id
  tags = {
    Name = "gw-dynamodb"
  }
}

########## Security Group ##########
resource "aws_security_group" "security_group" {
   vpc_id = aws_vpc.vpc.id
   ingress {
    description      = "HTTPS for Endpoint Interface "
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
########## Interface Endpoint Lambda ##########
resource "aws_vpc_endpoint" "in-lambda" {
  vpc_id = aws_vpc.vpc.id
  vpc_endpoint_type = "Interface"
  service_name    = "com.amazonaws.${var.aws_region}.lambda"
  subnet_ids = [
    aws_subnet.subnets[1].id,
    aws_subnet.subnets[5].id,
    aws_subnet.subnets[9].id
  ]
  private_dns_enabled = true
  security_group_ids = [aws_security_group.security_group.id]
  tags = {
    Name = "in-lambda"
  }

}

########## Network ACl ##########
resource "aws_network_acl" "umair-l1" {
  vpc_id = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.subnets[0].id, aws_subnet.subnets[4].id, aws_subnet.subnets[8].id]
  tags = {
    Name = "${var.project}-l1"
  }
}


resource "aws_network_acl_rule" "umair-l1-in" {
  count = length(var.l2_subnets_cidr)
  network_acl_id = aws_network_acl.umair-l1.id
  rule_number    = 1 + count.index
  egress         = false
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = element([for idx in var.l2_subnets_cidr : aws_subnet.subnets[idx].cidr_block], count.index)
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "umair-l1-out" {
  count = length(var.l2_subnets_cidr)
  network_acl_id = aws_network_acl.umair-l1.id
  rule_number    = 1 + count.index
  egress         = true
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = element([for idx in var.l2_subnets_cidr : aws_subnet.subnets[idx].cidr_block], count.index)
  from_port      = 22
  to_port        = 22
}


resource "aws_network_acl" "umair-l2" {
  vpc_id = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.subnets[1].id, aws_subnet.subnets[2].id, aws_subnet.subnets[5].id, aws_subnet.subnets[6].id, aws_subnet.subnets[9].id, aws_subnet.subnets[10].id]
  tags = {
    Name = "${var.project}-l2"
  }
}

resource "aws_network_acl_rule" "umair-l2-in" {
  count = length(var.l1_l3_subnets_cidr)
  network_acl_id = aws_network_acl.umair-l2.id
  rule_number    = 1 + count.index
  egress         = false
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = element([for idx in var.l1_l3_subnets_cidr : aws_subnet.subnets[idx].cidr_block], count.index)
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "umair-l2-out" {
  count = length(var.l1_l3_subnets_cidr)
  network_acl_id = aws_network_acl.umair-l2.id
  rule_number    = 1 + count.index
  egress         = true
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = element([for idx in var.l1_l3_subnets_cidr : aws_subnet.subnets[idx].cidr_block], count.index)
  from_port      = 22
  to_port        = 22
}


resource "aws_network_acl" "umair-l3" {
  vpc_id = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.subnets[3].id, aws_subnet.subnets[7].id, aws_subnet.subnets[11].id]
  tags = {
    Name = "${var.project}-l3"
  }
}

resource "aws_network_acl_rule" "umair-l3-in" {
  count = length(var.l2_subnets_cidr)
  network_acl_id = aws_network_acl.umair-l3.id
  rule_number    = 1 + count.index
  egress         = false
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = element([for idx in var.l2_subnets_cidr : aws_subnet.subnets[idx].cidr_block], count.index)
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "umair-l3-out" {
  count = length(var.l2_subnets_cidr)
  network_acl_id = aws_network_acl.umair-l3.id
  rule_number    = 1 + count.index
  egress         = true
  protocol       = "all"
  rule_action    = "allow"
  cidr_block     = element([for idx in var.l2_subnets_cidr : aws_subnet.subnets[idx].cidr_block], count.index)
  from_port      = 22
  to_port        = 22
}

########## Route Table Association ##########
resource "aws_route_table_association" "public_rtb_subnet_association" {
  count = length(var.l1_subnets_cidr)

  subnet_id      = element(aws_subnet.subnets, var.l1_subnets_cidr[count.index]).id
  route_table_id = aws_route_table.public_rtb.id

}

resource "aws_route_table_association" "l2_private_rtb_subnet_association" {
  count = length(aws_route_table.l2_private_rtb)
  subnet_id      = count.index < 2 ? aws_subnet.subnets[count.index+1].id : count.index < 4 ? aws_subnet.subnets[count.index+3].id : aws_subnet.subnets[count.index+5].id
  route_table_id = aws_route_table.l2_private_rtb[count.index].id

}

resource "aws_route_table_association" "l3_private_rtb_subnet_association" {
  count = length(aws_route_table.l3_private_rtb)
  subnet_id      = count.index ==0  ? aws_subnet.subnets[count.index+3].id : count.index == 1 ? aws_subnet.subnets[count.index+6].id : aws_subnet.subnets[count.index+9].id
  route_table_id = aws_route_table.l3_private_rtb[count.index].id

}

########## SSH KEY ##########

resource "tls_private_key" "infra_pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "infra_kp" {
  key_name   = "infra"       # Create "infra" to AWS!!
  public_key = tls_private_key.infra_pk.public_key_openssh

  provisioner "local-exec" { # Create "infra.pem" to your computer!!
    command = "echo '${tls_private_key.infra_pk.private_key_pem}' > ./infra.pem"
  }
}

########## OUTPUT VALUES ##########

output "subnet_ids" {
  value = aws_subnet.subnets[*]
}

output "infra-ssh-key" {
  value = aws_key_pair.infra_kp
}
