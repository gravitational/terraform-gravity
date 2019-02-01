//
// SQS is used as a notification mechanism for auto scale group lifecycle hooks
// Every time when instance is added to ASG, or removed from ASG
// AWS sends a message to SQS queue

resource "aws_sqs_queue" "lifecycle_hooks" {
  name                      = "${local.safe_name}"
  receive_wait_time_seconds = 10
}

data "aws_iam_policy_document" "sqs-autoscale-lifecycle-hook-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["autoscaling.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lifecycle_hooks" {
  name = "${var.name}-lifecycle-hooks"
  tags = "${merge(local.common_tags, map())}"

  assume_role_policy = "${data.aws_iam_policy_document.sqs-autoscale-lifecycle-hook-assume-role-policy.json}"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "sqs-autoscale-lifecycle-hook-crud" {
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueUrl",
      "sns:Publish",
    ]

    resources = ["${aws_sqs_queue.lifecycle_hooks.arn}"]
  }
}

# Attach policy document for access to the sqs queue
resource "aws_iam_role_policy" "lifecycle_hooks" {
  name = "${var.name}-lifecycle-hooks"
  role = "${aws_iam_role.lifecycle_hooks.id}"

  policy = "${data.aws_iam_policy_document.sqs-autoscale-lifecycle-hook-crud.json}"

  lifecycle {
    create_before_destroy = true
  }
}
