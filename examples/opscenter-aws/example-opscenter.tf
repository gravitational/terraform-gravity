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
  source              = "../../aws/vpc"
  name                = "${local.name}"
  enable_internet     = true
  enable_nat_instance = false
  ssh_key_name        = "ops"
  tags                = "${local.tags}"
}

module "gravity" {
  //source          = "github.com/gravitational/terraform-gravity//aws?ref=304ab9386e3f85b6b5f91340f0c69b2cdc7582b1"
  source                      = "../../aws/"
  name                        = "${local.name}"
  key_name                    = "ops"
  tags                        = "${local.tags}"
  master_count                = 3
  worker_count                = 2
  subnets                     = ["10.1.1.0/24"]
  availability_zones          = "${module.vpc.availability_zones}"
  internet_gateway            = "${module.vpc.internet_gateway}"
  master_ami                  = "${data.aws_ami.base.id}"
  worker_ami                  = "${data.aws_ami.base.id}"
  vpc_id                      = "${module.vpc.id}"
  associate_public_ip_address = true

  dl_url = "opscenter:5.0.11"

  //dl_url = "s3://knisbet-test/opscenter.tar"

  ops_advertise_addr   = "${local.name}:443"
  aws_hosted_zone_name = "gravitational.io."
  email                = "ops@gravitational.com"
  # Setup initial admin OIDC
  oidc_client_id     = "${var.oidc_client_id}"
  oidc_client_secret = "${var.oidc_client_secret}"
  oidc_claim         = "gravitational/devc"
  oidc_issuer_url    = "https://gravitational.auth0.com/"
}

module "telekube" {
  //source          = "github.com/gravitational/terraform-gravity//aws?ref=304ab9386e3f85b6b5f91340f0c69b2cdc7582b1"
  source             = "../../aws/"
  name               = "tf-cluster1.gravitational.io"
  key_name           = "ops"
  tags               = "${local.tags}"
  master_count       = 3
  worker_count       = 2
  subnets            = ["10.1.2.0/24"]
  availability_zones = "${module.vpc.availability_zones}"
  internet_gateway   = "${module.vpc.internet_gateway}"
  master_ami         = "${data.aws_ami.base.id}"
  worker_ami         = "${data.aws_ami.base.id}"
  vpc_id             = "${module.vpc.id}"

  associate_public_ip_address = true

  dl_url = "telekube:5.0.11"
  flavor = "one"

  // trusted cluster
  trusted_cluster_host  = "${local.name}"
  trusted_cluster_token = "${module.gravity.secret_trusted_cluster_token}"
}

module "telekube2" {
  //source          = "github.com/gravitational/terraform-gravity//aws?ref=304ab9386e3f85b6b5f91340f0c69b2cdc7582b1"
  source                      = "../../aws/"
  name                        = "tf-cluster2.gravitational.io"
  key_name                    = "ops"
  tags                        = "${local.tags}"
  master_count                = 3
  worker_count                = 0
  subnets                     = ["10.1.3.0/24"]
  availability_zones          = "${module.vpc.availability_zones}"
  internet_gateway            = "${module.vpc.internet_gateway}"
  master_ami                  = "${data.aws_ami.base.id}"
  worker_ami                  = "${data.aws_ami.base.id}"
  vpc_id                      = "${module.vpc.id}"
  associate_public_ip_address = true

  dl_url = "telekube:5.0.10"
  flavor = "one"
}

provider "aws" {
  region  = "us-east-1"
  version = "1.40.0"
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

output "ops_token" {
  value = "${module.gravity.secret_admin_token}"
}

output "cluster1_token" {
  value = "${module.telekube.secret_admin_token}"
}

output "cluster2_token" {
  value = "${module.telekube2.secret_admin_token}"
}
