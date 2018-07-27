//
// Subnet
//
resource "aws_subnet" "k8s" {
  count = "${length(var.subnets)}"

  vpc_id            = "${var.vpc_id}"
  cidr_block        = "${element(var.subnets, count.index)}"
  availability_zone = "${element(var.availability_zones, count.index)}"

  //map_public_ip_on_launch = "${var.associate_public_ip_address}"

  tags = "${local.merged_tags}"
}

//
// Route Table
//
resource "aws_route_table" "k8s" {
  count  = "${length(var.subnets)}"
  vpc_id = "${var.vpc_id}"

  tags = "${local.merged_tags}"
}

//
// Defualt Route
//
// TODO(knisbet) support private networks
resource "aws_route" "internet" {
  route_table_id         = "${aws_route_table.k8s.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${var.internet_gateway}"
}

//
// Route Table Association
//

resource "aws_route_table_association" "k8s" {
  count          = "${length(var.subnets)}"
  subnet_id      = "${element(aws_subnet.k8s.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.k8s.*.id, count.index)}"
}
