variable name {
  description = "Name of the VPC"
}

variable "cidr" {
  description = "The CIDR subnet for the VPC."
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "User tags to add to the created AWS resources"
  type        = "map"
}

variable "instance_tenancy" {
  description = "The instance tenancy to use in the VPC [default/dedicated]"
  default     = "default"
}

variable "enable_dns_support" {
  description = "Enable DNS support"
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames"
  default     = true
}

variable "enable_internet_gateway" {
  description = "Enable VPC internet Gateway"
  default     = true
}

locals {
  common_tags = {
    "Name" = "${var.name}"
  }
}

//
// VPC
//

resource "aws_vpc" "main" {
  cidr_block           = "${var.cidr}"
  instance_tenancy     = "${var.instance_tenancy}"
  enable_dns_support   = "${var.enable_dns_support}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"

  tags = "${merge(local.common_tags, var.tags)}"
}

//
// AMIs
//

data "aws_ami" "nat_ami" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat*"]
  }
}

//
// Gateways
//
resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags = "${merge(local.common_tags, var.tags)}"
}

//
// Outputs
//

// The VPC ID
output "id" {
  value = "${aws_vpc.main.id}"
}

output "cidr" {
  value = "${aws_vpc.main.cidr_block}"
}

output "internet_gateway" {
  value = "${aws_internet_gateway.main.id}"
}
