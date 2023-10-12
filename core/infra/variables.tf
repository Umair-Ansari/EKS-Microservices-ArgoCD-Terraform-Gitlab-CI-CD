variable "project" {
  description = "Name of project"
  default     = "umair"
}

variable "aws_region" {
  description = "AWS region"
  default     = "me-central-1"
}


variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.20.0.0/16"
}

variable "subnet_count" {
  description = "Number of subnets to create"
  default     = 12
}

variable "public_subnet_count" {
  description = "Number of public subnets to create"
  default     = 3
}

variable "availability_zones" {
  description = "List of availability zones"
  default     = ["me-central-1a", "me-central-1b", "me-central-1c"]
}


variable "subnets_tags" {
 default  = ["l1-1-1a", "l2-1-1a", "l2-3-1a", "l3-1-1a", "l1-2-1b", "l2-2-1b", "l2-4-1b", "l3-2-1b", "l1-3-1c", "l2-5-1c", "l2-6-1c", "l3-3-1c"]
}

variable "route_table_tags" {
 default  = ["l2-1-1a", "l2-3-1a", "l3-1-1a", "l2-2-1a", "l2-4-1a", "l3-2-1b", "l2-5-1a", "l2-6-1a", "l3-3-1c"]
}
variable "l2_route_table_tags" {
 default  = ["l2-1-1a", "l2-3-1a",  "l2-2-1b", "l2-4-1b", "l2-5-1c", "l2-6-1c"]
}
variable "l3_route_table_tags" {
 default  = ["l3-1-1a",  "l3-2-1b", "l3-3-1c"]
}

variable "l1_l3_subnets_cidr" {
  type    = list(number)
  default = [0, 4, 8, 3, 7, 11]
}

variable "l1_subnets_cidr" {
  type    = list(number)
  default = [0, 4, 8]
}

variable "l2_subnets_cidr" {
  type    = list(number)
  default = [1, 2, 5, 6 ,9,10]
}

