//
// Autoscaling group
//
resource "aws_autoscaling_group" "master" {
  name_prefix = "${var.name}-master-"

  # TODO(knisbet) hard code this to a fixed size set of masters
  max_size                  = "5"
  min_size                  = "0"
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = "${var.master_count}"
  force_delete              = false
  launch_configuration      = "${aws_launch_configuration.master.name}"
  vpc_zone_identifier       = ["${aws_subnet.k8s.*.id}"]
  default_cooldown          = 30

  // external autoscale algos can modify these values,
  // so ignore changes to them
  lifecycle {
    ignore_changes        = ["desired_capacity", "max_size", "min_size"]
    create_before_destroy = true
  }

  tags = ["${local.asg_tags}"]

  depends_on = ["aws_launch_configuration.master"]
}

//
// Launch Configuration
//
resource "aws_launch_configuration" "master" {
  name_prefix                 = "${var.name}-lc-master-"
  image_id                    = "${var.master_ami}"
  instance_type               = "${var.master_instance_type}"
  user_data                   = "${data.template_cloudinit_config.master.rendered}"
  key_name                    = "${var.key_name}"
  ebs_optimized               = true
  associate_public_ip_address = "${var.associate_public_ip_address}"
  security_groups             = ["${aws_security_group.kubernetes.id}"]
  iam_instance_profile        = "${aws_iam_instance_profile.master.id}"

  root_block_device {
    delete_on_termination = true
    volume_type           = "io1"
    volume_size           = "50"
    iops                  = 500
  }

  // /var/lib/gravity
  ebs_block_device = {
    delete_on_termination = true
    volume_type           = "io1"
    volume_size           = "500"
    device_name           = "/dev/xvdb"
    iops                  = 1500
  }

  // /var/lib/gravity/etcd
  ebs_block_device = {
    delete_on_termination = true
    volume_type           = "io1"
    volume_size           = "100"
    device_name           = "/dev/xvdc"
    iops                  = 1500
  }

  lifecycle {
    create_before_destroy = true
  }
}

//
// Node Profile
//
resource "aws_iam_instance_profile" "master" {
  name       = "${var.name}-master"
  role       = "${aws_iam_role.master.name}"
}
