locals {
  name = "tf-ops.gravitational.io"

  tags = {
    "gravitational.io/vpc"  = "true"
    description             = "Example Terraform"
    "gravitational.io/user" = "kevin"
  }
}

//
// Load OIDC secrets from terminal
//
variable "oidc_client_id" {
  default = ""
}

variable "oidc_client_secret" {
  default = ""
}

// Create a new VPC for the ops center cluster
module "vpc" {
  //source              = "github.com/gravitational/terraform-gravity//aws/vpc?ref=304ab9386e3f85b6b5f91340f0c69b2cdc7582b1"
  source = "../../aws/vpc"
  name   = local.name

  tags = local.tags
  // cidr = "10.1.0.0/16"
  // public_subnets = ["10.1.0.0/24"]
}
/*
module "ops_center_network" {
  source = "../../aws/network/"

  name = local.name
  cidr = cidrsubnet(module.vpc.cidr, 6, 0) // assign a /22 to this cluster

  availability_zones = ["us-east-1a", "us-east-1b"]
  vpc_id             = module.vpc.id
  tags               = local.tags
  internet_gateway   = module.vpc.internet_gateway
  enable_security_group = true
  associate_public_ip_address = true
}*/
/*
output "default_security_group" {
  value = module.ops_center_network.default_security_group
}*/

output "tags" {
  value = local.tags
}
/*
module "ops_center" {
  //source          = "github.com/gravitational/terraform-gravity//aws?ref=304ab9386e3f85b6b5f91340f0c69b2cdc7582b1"
  source       = "../../aws/"
  name         = local.name
  key_name     = "ops"
  tags         = local.tags
  master_count = 1
  worker_count = 0
  skip_install = false

  availability_zones          = module.ops_center_network.availability_zones
  master_ami                  = data.aws_ami.base.id
  worker_ami                  = data.aws_ami.base.id
  vpc_id                      = module.vpc.id
  master_security_group       = module.ops_center_network.default_security_group
  worker_security_group       = module.ops_center_network.default_security_group
  subnets                     = module.ops_center_network.public_subnet_ids
  associate_public_ip_address = true

  dl_url = "opscenter:6.2.0"

  //dl_url = "s3://knisbet-test/opscenter.tar"

  ops_advertise_addr   = "${local.name}:443"
  aws_hosted_zone_name = "gravitational.io."
  email                = "ops@gravitational.com"

  # Setup initial admin OIDC
  oidc_client_id     = var.oidc_client_id
  oidc_client_secret = var.oidc_client_secret
  oidc_claim         = "gravitational/devc"
  oidc_issuer_url    = "https://gravitational.auth0.com/"
}*/

module "cluster1_network" {
  source = "../../aws/network/"

  name = "tf-cluster1.gravitational.io"
  cidr = cidrsubnet(module.vpc.cidr, 6, 1) // assign a /22 to this cluster

  availability_zones          = ["us-east-1a", "us-east-1b"]
  vpc_id                      = module.vpc.id
  tags                        = local.tags
  internet_gateway            = module.vpc.internet_gateway
  enable_security_group       = true
  associate_public_ip_address = true
}

module "cluster1" {
  //source          = "github.com/gravitational/terraform-gravity//aws?ref=304ab9386e3f85b6b5f91340f0c69b2cdc7582b1"
  source       = "../../aws/"
  name         = "tf-cluster1.gravitational.io"
  key_name     = "ops"
  tags         = local.tags
  master_count = 3
  worker_count = 1

  master_ami                  = data.aws_ami.base.id
  worker_ami                  = data.aws_ami.base.id
  vpc_id                      = module.vpc.id
  availability_zones          = module.cluster1_network.availability_zones
  master_security_group       = module.cluster1_network.default_security_group
  worker_security_group       = module.cluster1_network.default_security_group
  subnets                     = module.cluster1_network.public_subnet_ids
  associate_public_ip_address = true

  dl_url = "telekube:6.2.5"
  flavor = "one"

  // trusted cluster
  //trusted_cluster_host  = local.name
  //trusted_cluster_token = module.ops_center.secret_trusted_cluster_token
}

/*
module "cluster2_network" {
  source = "../../aws/network/"

  name = "tf-cluster2.gravitational.io"
  cidr = "${cidrsubnet(module.vpc.cidr, 6, 2)}" // assign a /22 to this cluster

  availability_zones = ["us-east-1a", "us-east-1b"]
  vpc_id             = "${module.vpc.id}"
  tags               = "${local.tags}"
  internet_gateway   = "${module.vpc.internet_gateway}"

  // enable_public_elb = true
  // enable_security_group = true
  // associate_public_ip_address = false
}

module "cluster2" {
  //source          = "github.com/gravitational/terraform-gravity//aws?ref=304ab9386e3f85b6b5f91340f0c69b2cdc7582b1"
  source       = "../../aws/"
  name         = "tf-cluster2.gravitational.io"
  key_name     = "ops"
  tags         = "${local.tags}"
  master_count = 1
  worker_count = 0

  master_ami                  = "${data.aws_ami.base.id}"
  worker_ami                  = "${data.aws_ami.base.id}"
  vpc_id                      = "${module.vpc.id}"
  availability_zones          = "${module.cluster2_network.availability_zones}"
  master_security_group       = "${module.cluster2_network.default_security_group}"
  worker_security_group       = "${module.cluster2_network.default_security_group}"
  subnets                     = "${module.cluster2_network.private_subnet_ids}"
  associate_public_ip_address = false

  dl_url = "telekube:5.2.0"
  flavor = "one"

  // trusted cluster
  trusted_cluster_host  = "${local.name}"
  trusted_cluster_token = "${module.ops_center.secret_trusted_cluster_token}"
}
*/

provider "aws" {
  region  = "us-east-1"
  version = "2.31.0"
}

// TODO(knisbet) make sure this works with a public AMI
/*data "aws_ami" "base" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["centos-7-k8s-base-ami *"]
  }
}*/

data "aws_ami" "base" {
  owners      = ["679593333241"] // AWS Marketplace - TODO: not clear how this ensures the ami really comes from centos??
  most_recent = true

  filter {
    name   = "name"
    values = ["CentOS Linux 7 x86_64 HVM EBS *"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

/*output "ops_token" {
  value = module.ops_center.secret_admin_token
}*/

/*
output "cluster1_token" {
  value = "${module.telekube.secret_admin_token}"
}

output "cluster2_token" {
  value = "${module.telekube2.secret_admin_token}"
}
*/
