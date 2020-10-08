//
// ASG Hooks
//
resource "aws_autoscaling_lifecycle_hook" "master-launching" {
  name                   = "${local.safe_name}-master-launching"
  autoscaling_group_name = aws_autoscaling_group.master.name
  default_result         = "CONTINUE"
  heartbeat_timeout      = 60
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"

  notification_metadata = <<EOF
  {
	"KubernetesCluster": "${var.name}"
  }
  EOF

  notification_target_arn = aws_sqs_queue.lifecycle_hooks.arn
  role_arn                = aws_iam_role.lifecycle_hooks.arn

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_lifecycle_hook" "master-terminating" {
  name                   = "${local.safe_name}-master-terminating"
  autoscaling_group_name = aws_autoscaling_group.master.name
  default_result         = "CONTINUE"
  heartbeat_timeout      = 60
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"

  notification_metadata = <<EOF
  {
	"KubernetesCluster": "${var.name}"
  }
  EOF

  notification_target_arn = aws_sqs_queue.lifecycle_hooks.arn
  role_arn                = aws_iam_role.lifecycle_hooks.arn

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_lifecycle_hook" "worker-launching" {
  name                   = "${local.safe_name}-worker-launching"
  autoscaling_group_name = aws_autoscaling_group.worker.name
  default_result         = "CONTINUE"
  heartbeat_timeout      = 60
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"

  notification_metadata = <<EOF
  {
	"KubernetesCluster": "${var.name}"
  }
  EOF

  notification_target_arn = aws_sqs_queue.lifecycle_hooks.arn
  role_arn                = aws_iam_role.lifecycle_hooks.arn

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_lifecycle_hook" "worker-terminating" {
  name                   = "${local.safe_name}-worker-terminating"
  autoscaling_group_name = aws_autoscaling_group.worker.name
  default_result         = "CONTINUE"
  heartbeat_timeout      = 60
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"

  notification_metadata = <<EOF
  {
	"KubernetesCluster": "${var.name}"
  }
  EOF

  notification_target_arn = aws_sqs_queue.lifecycle_hooks.arn
  role_arn                = aws_iam_role.lifecycle_hooks.arn

  lifecycle {
    create_before_destroy = true
  }
}
