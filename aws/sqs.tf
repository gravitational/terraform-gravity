//
// SQS is used as a notification mechanism for auto scale group lifecycle hooks
// Every time when instance is added to ASG, or removed from ASG
// AWS sends a message to SQS queue

resource "aws_sqs_queue" "lifecycle_hooks" {
  name                      = "${local.safe_name}"
  receive_wait_time_seconds = 10
}

resource "aws_iam_role" "lifecycle_hooks" {
  name = "${var.name}-lifecycle-hooks"

  assume_role_policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
	  {
		"Sid": "",
		"Effect": "Allow",
		"Principal": {
		  "Service": "autoscaling.amazonaws.com"
		},
		"Action": "sts:AssumeRole"
	  }
	]
}
EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Attach policy document for access to the sqs queue
resource "aws_iam_role_policy" "lifecycle_hooks" {
  name = "${var.name}-lifecycle-hooks"
  role = "${aws_iam_role.lifecycle_hooks.id}"

  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [{
	  "Effect": "Allow",
	  "Resource": "${aws_sqs_queue.lifecycle_hooks.arn}",
	  "Action": [
		"sqs:SendMessage",
		"sqs:GetQueueUrl",
		"sns:Publish"
	  ]
	}]
}
EOF

  lifecycle {
    create_before_destroy = true
  }
}
