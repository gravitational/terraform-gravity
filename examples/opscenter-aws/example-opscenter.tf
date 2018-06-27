// Create a new VPC for the ops center cluster
module "vpc" {
  source              = "github.com/gravitational/terraform-gravity//aws/vpc?ref=fb675391312f0fe9eb6fa1d1c4d4de039f00a661"
  name                = "example.gravitational.io"
  enable_internet     = true
  enable_nat_instance = true
  ssh_key_name        = "ops"

  tags = {
    "gravitational.io/vpc"  = ""
    description             = "Example Terraform VPC"
    "gravitational.io/user" = "kevin"
  }
}

provider "aws" {
  region = "us-east-1"
}
