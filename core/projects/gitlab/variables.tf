variable "subnet_id" {}
variable "ssh-key" {}
variable "r53_domain" {}
variable "gitlab_subdomain" {}
variable "l1_subnets" {
    type    = list(string)
}
variable "vpc" {}