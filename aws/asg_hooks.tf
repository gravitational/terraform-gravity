//
// ASG Hooks
//
resource "aws_autoscaling_lifecycle_hook" "launching" {
  name                   = "${local.safe_name}-launching"
  autoscaling_group_name = "${aws_autoscaling_group.master.name}"
  default_result         = "CONTINUE"
  heartbeat_timeout      = 60
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"

  notification_metadata = <<EOF
  {
	"KubernetesCluster": "${var.name}"
  }
  EOF

  notification_target_arn = "${aws_sqs_queue.lifecycle_hooks.arn}"
  role_arn                = "${aws_iam_role.lifecycle_hooks.arn}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_lifecycle_hook" "terminating" {
  name                   = "${local.safe_name}-terminating"
  autoscaling_group_name = "${aws_autoscaling_group.master.name}"
  default_result         = "CONTINUE"
  heartbeat_timeout      = 60
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"

  notification_metadata = <<EOF
  {
	"KubernetesCluster": "${var.name}"
  }
  EOF

  notification_target_arn = "${aws_sqs_queue.lifecycle_hooks.arn}"
  role_arn                = "${aws_iam_role.lifecycle_hooks.arn}"

  lifecycle {
    create_before_destroy = true
  }
}
