########## Create VPC ##########
module "vpc" {
  source = "./infra"
}

########## Create Gitlab Server ##########
module "gitlab" {
  source = "./projects/gitlab"
  subnet_id = module.vpc.subnet_ids[1].id # l2-1a subnet
  ssh-key = module.vpc.infra-ssh-key.id
  r53_domain = "sac-stg.org"
  gitlab_subdomain = "gitlab-ci"
  vpc = module.vpc.vpc
  l1_subnets = [module.vpc.subnet_ids[0].id, module.vpc.subnet_ids[4].id, module.vpc.subnet_ids[8].id]
}


########## Create Jump Server ##########
module "jump-host" {
  source = "./projects/jump-host"
  subnet_id = module.vpc.subnet_ids[0].id # l1-1a subnet
  ssh-key = module.vpc.infra-ssh-key.id
  ssh-sg = module.vpc.infra-ssh-sg.id
}
