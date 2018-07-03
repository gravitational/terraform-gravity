locals {
  name = "terraform-example.gravitational.io"

  tags = {
    "gravitational.io/vpc"  = ""
    description             = "Example Terraform VPC"
    "gravitational.io/user" = "kevin"
  }
}

// Create a new VPC for the ops center cluster
module "vpc" {
  //source              = "github.com/gravitational/terraform-gravity//aws/vpc?ref=304ab9386e3f85b6b5f91340f0c69b2cdc7582b1"
  source              = "../../aws/vpc"
  name                = "${local.name}"
  enable_internet     = true
  enable_nat_instance = true
  ssh_key_name        = "ops"
  tags                = "${local.tags}"
}

module "gravity" {
  //source          = "github.com/gravitational/terraform-gravity//aws?ref=304ab9386e3f85b6b5f91340f0c69b2cdc7582b1"
  source         = "../../aws/"
  name           = "${local.name}"
  key_name       = "ops"
  tags           = "${local.tags}"
  master_count   = 3
  worker_count   = 0
  aws_subnet_ids = "${module.vpc.private_subnets}"
  master_ami     = "${data.aws_ami.base.id}"
  worker_ami     = "${data.aws_ami.base.id}"
  vpc_id         = "${module.vpc.id}"
}

provider "aws" {
  region = "us-east-1"
}

// TODO(knisbet) make sure this works with a public AMI
data "aws_ami" "base" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["centos-7-k8s-base-ami *"]
  }
}
