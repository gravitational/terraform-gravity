variable name {
  description = "Name of the gravity cluster"
}

variable "cidr" {
  description = "The cidr subnet to assign for this cluster."
}

variable "availability_zones" {
  description = "List of availability_zones to spread the provided subnets"
  type        = "list"
}

variable "vpc_id" {
  description = "The VPC we're using"
  type        = "string"
}

variable "enable_security_group" {
  description = "Enable creation of default security group"
  default     = true
}

variable "associate_public_ip_address" {
  description = "Associate public IP to launched instances"
  default     = false
}

variable "tags" {
  description = "Tags to add to the AWS resources"
  type        = "map"
}

variable "internet_gateway" {
  description = "internet gateway of the VPC"
}

// safe cluster name to use in places sensitive to naming, e.g. SQS queues and lifecycle hooks
locals {
  safe_name = "${replace(var.name, "/[^a-zA-Z0-9\\-]/", "")}"

  common_tags = {
    "Name"                              = "${var.name}"
    "KubernetesCluster"                 = "${var.name}"
    "kubernetes.io/cluster/${var.name}" = "owned"
    Terraform                           = "true"
  }

  merged_tags = "${merge(local.common_tags, var.tags)}"
}

//
// Subnet
//

// Subnet for all the kubernetes nodes
resource "aws_subnet" "private" {
  count = "${length(var.availability_zones)}"

  vpc_id = "${var.vpc_id}"

  cidr_block        = "${cidrsubnet(var.cidr, 3, count.index * 2)}"
  availability_zone = "${element(var.availability_zones, count.index)}"
  tags              = "${merge(local.merged_tags, map("kubernetes.io/role/internal-elb", ""))}"
}

resource "aws_subnet" "public" {
  count = "${length(var.availability_zones)}"

  vpc_id = "${var.vpc_id}"

  cidr_block        = "${cidrsubnet(var.cidr, 3, count.index * 2 + 1)}"
  availability_zone = "${element(var.availability_zones, count.index)}"
  tags              = "${merge(local.merged_tags, map("kubernetes.io/role/elb", ""))}"
}

//
// Route Table
//
resource "aws_route_table" "private" {
  count  = "${length(var.availability_zones)}"
  vpc_id = "${var.vpc_id}"

  tags = "${local.merged_tags}"
}

resource "aws_route_table" "public" {
  count  = "${length(var.availability_zones)}"
  vpc_id = "${var.vpc_id}"

  tags = "${local.merged_tags}"
}

//
// Defualt Route
//
resource "aws_route" "public_internet" {
  count                  = "${length(var.availability_zones)}"
  route_table_id         = "${element(aws_route_table.public.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${var.internet_gateway}"
}

resource "aws_route" "private_internet" {
  count                  = "${length(var.availability_zones)}"
  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.main.*.id, count.index)}"
}

//
// Route Table Association
//

resource "aws_route_table_association" "private" {
  count          = "${length(var.availability_zones)}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "public" {
  count          = "${length(var.availability_zones)}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.public.*.id, count.index)}"
}

//
// Nat Gateway
//
resource "aws_nat_gateway" "main" {
  count         = "${length(var.availability_zones)}"
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"

  tags = "${merge(local.common_tags, var.tags)}"
}

//
// Elastic IPs for NAT
//
resource "aws_eip" "nat" {
  count = "${length(var.availability_zones)}"

  vpc = true
}

//
// Default security group
//
resource "aws_security_group" "kubernetes" {
  count = "${var.enable_security_group ? 1 : 0}"

  name   = "${var.name}"
  vpc_id = "${var.vpc_id}"
  tags   = "${merge(local.common_tags, var.tags)}"
}

resource "aws_security_group_rule" "ingress_allow_ssh" {
  count = "${var.enable_security_group ? 1 : 0}"

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  //security_group_id = "${aws_security_group.kubernetes.id}"
  security_group_id = "${element(concat(aws_security_group.kubernetes.*.id, list("")), 0)}"
}

resource "aws_security_group_rule" "ingress_allow_internal_traffic" {
  count = "${var.enable_security_group ? 1 : 0}"

  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  //security_group_id = "${aws_security_group.kubernetes.id}"
  security_group_id = "${element(concat(aws_security_group.kubernetes.*.id, list("")), 0)}"
}

resource "aws_security_group_rule" "egress_allow_all_traffic" {
  count = "${var.enable_security_group ? 1 : 0}"

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  //security_group_id = "${aws_security_group.kubernetes.id}"
  security_group_id = "${element(concat(aws_security_group.kubernetes.*.id, list("")), 0)}"
}

output "default_security_group" {
  value = "${element(aws_security_group.kubernetes.*.id, 0)}"
}

output "public_subnet_ids" {
  value = aws_subnet.public.*.id
}

output "private_subnet_ids" {
  value      = aws_subnet.private.*.id
  depends_on = ["aws_nat_gateway.main"]
}

output "availability_zones" {
  value = ["{var.availability_zones}"]
}
