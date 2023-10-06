########## Create VPC ##########
module "vpc" {
  source = "./infra"
}

########## Create Gitlab Server ##########
module "gitlab" {
  source = "./projects/gitlab"
  subnet_id = module.vpc.subnet_ids[1].id # l2-1a subnet
  ssh-key = module.vpc.infra-ssh-key.id
}
