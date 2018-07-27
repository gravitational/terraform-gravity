variable name {
  description = "Name of the VPC"
}

variable "cidr" {
  description = "The CIDR block for the VPC."
  default     = "10.1.0.0/16"
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

variable "enable_nat_instance" {
  description = "Use cheaper instances to reach internet via NAT"
  default     = false
}

variable "enable_nat_gateway" {
  description = "Use AWS NAT gateways to reach internet via NAT"
  default     = false
}

variable "enable_internet" {
  description = "Enable provisioning internet gateway (can be disabled to completely isolate internet access)"
  default     = true
}

variable "availability_zones" {
  description = "List of availability zones to install subnets in"
  type        = "list"
  default     = ["us-east-1b"]
}

variable "public_subnets" {
  description = "List of subnets to be created that can be assigned public IPs"
  type        = "list"
  default     = ["10.1.0.0/24"]
}

variable "private_subnets" {
  description = "List of subnets to be created that can only be used privately (but can reach internet via NAT)"
  type        = "list"
  default     = ["10.1.128.0/20"]
}

variable "ssh_key_name" {
  description = "SSH key name to use for any launched instances"
  default     = ""
}

variable "nat_instance_type" {
  description = "The AWS instance type to use for NAT (only if using nat instances)"
  default     = "t2.nano"
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
// Subnets
//
resource "aws_subnet" "public" {
  count = "${length(var.public_subnets)}"

  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${element(var.public_subnets, count.index)}"
  availability_zone       = "${element(var.availability_zones, count.index)}"
  map_public_ip_on_launch = true

  tags = "${merge(local.common_tags, var.tags)}"
}

resource "aws_subnet" "private" {
  count = "${length(var.private_subnets)}"

  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${element(var.private_subnets, count.index)}"
  availability_zone = "${element(var.availability_zones, count.index)}"

  tags = "${merge(local.common_tags, var.tags)}"
}

//
// Gateways
//
resource "aws_internet_gateway" "main" {
  count  = "${0 + var.enable_internet}"
  vpc_id = "${aws_vpc.main.id}"

  tags = "${merge(local.common_tags, var.tags)}"
}

resource "aws_nat_gateway" "main" {
  count         = "${(0 + var.enable_nat_gateway) * length(var.availability_zones)}"
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  depends_on    = ["aws_internet_gateway.main"]

  tags = "${merge(local.common_tags, var.tags)}"
}

// AWS instance used as a NAT gateway
resource "aws_instance" "nat" {
  count             = "${(0 + var.enable_nat_instance) * length(var.availability_zones)}"
  availability_zone = "${element(var.availability_zones, count.index)}"

  tags = "${merge(local.common_tags, var.tags)}"

  volume_tags = "${merge(local.common_tags, var.tags)}"

  key_name          = "${var.ssh_key_name}"
  ami               = "${data.aws_ami.nat_ami.id}"
  instance_type     = "${var.nat_instance_type}"
  source_dest_check = false

  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"

  vpc_security_group_ids = ["${aws_security_group.nat_instances.id}"]

  lifecycle {
    # Ignore changes to the NAT AMI data source.
    ignore_changes = ["ami"]
  }
}

//
// Elastic IPs
//
resource "aws_eip" "nat" {
  count = "${var.enable_nat_gateway * length(var.availability_zones)}"

  vpc = true
}

//
// Route Tables
// 
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  tags = "${merge(local.common_tags, var.tags)}"
}

resource "aws_route_table" "private" {
  count  = "${length(var.private_subnets)}"
  vpc_id = "${aws_vpc.main.id}"

  tags = "${merge(local.common_tags, var.tags)}"
}

//
// Routes
//
resource "aws_route" "via_nat_gateway" {
  count                  = "${var.enable_nat_gateway * length(compact(var.private_subnets))}"
  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.main.*.id, count.index)}"
}

resource "aws_route" "via_nat_instance" {
  count                  = "${(0 + var.enable_nat_instance) * length(compact(var.private_subnets))}"
  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = "${element(aws_instance.nat.*.id, count.index)}"
}

resource "aws_route" "internet" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.main.id}"
}

//
// Route Associations
//
resource "aws_route_table_association" "private" {
  count          = "${length(var.private_subnets)}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "public" {
  count          = "${length(var.public_subnets)}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

//
// Security Groups
//
resource "aws_security_group" "nat_instances" {
  # Use NAT instances (cheaper) instead of NAT gateways
  count       = "${0 + var.enable_nat_instance}"
  name        = "nat"
  description = "Allow traffic from clients into NAT instances"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = "${var.private_subnets}"
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = "${var.private_subnets}"
  }

  # Allow SSH to NAT instance to be used as a jump host
  # TODO(knisbet) make this optional
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${aws_vpc.main.id}"
  tags   = "${merge(local.common_tags, var.tags)}"
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
// Outputs
//

// The VPC ID
output "id" {
  value = "${aws_vpc.main.id}"
}

output "cidr_block" {
  value = "${aws_vpc.main.cidr_block}"
}

output "public_subnets" {
  value = ["${aws_subnet.public.*.id}"]
}

output "private_subnets" {
  value = ["${aws_subnet.private.*.id}"]
}

output "security_group" {
  value = "${aws_vpc.main.default_security_group_id}"
}

output "availability_zones" {
  value = ["${aws_subnet.public.*.availability_zone}"]
}

output "public_route_table" {
  value = ["${aws_route_table.public.*.id}"]
}

output "private_route_table" {
  value = ["${aws_route_table.private.*.id}"]
}

output "internet_gateway" {
  value = "${element(aws_internet_gateway.main.*.id, 0)}"
}
