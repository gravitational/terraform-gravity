// Create a new VPC for the ops center cluster
module "vpc" {
  source              = "github.com/gravitational/terraform-gravity//aws/vpc"
  name                = "example.gravitational.io"
  enable_internet     = true
  enable_nat_instance = true

  tags = {
    "gravitational.io/vpc"  = ""
    description             = "Example Terraform VPC"
    "gravitational.io/user" = "kevin"
  }
}
