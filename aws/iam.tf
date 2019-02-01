data "aws_kms_alias" "ssm" {
  name = "${var.kms_alias_name}"
}

data "aws_iam_policy_document" "master-instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "master" {
  name               = "${var.name}-master"
  tags               = "${merge(local.common_tags, map())}"
  assume_role_policy = "${data.aws_iam_policy_document.master-instance-assume-role-policy.json}"
}

data "aws_iam_policy_document" "master-instance-kubernetes-operations" {
  // Add the ability to let the cluster manage autos-scaling
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeTags",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]

    resources = ["*"]
  }

  // Manage all EC2 operations
  statement {
    actions   = ["ec2:*"]
    resources = ["*"]
  }

  // Manage all LB operations
  statement {
    actions   = ["elasticloadbalancing:*"]
    resources = ["*"]
  }

  // Masters can do read-only ECR operations
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:BatchGetImage",
    ]

    resources = ["*"]
  }

  // Route53 Management
  statement {
    actions = [
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:ChangeResourceRecordSets",
      "route53:GetChange",
    ]

    resources = ["*"]
  }

  //TODO(knisbet) make sure s3 bucket permissions are optional / uses dl_url to get the specific object
  statement {
    actions = ["s3:GetObject"]

    resources = [
      "arn:aws:s3:::knisbet-test/*",
    ]
  }
}

resource "aws_iam_role_policy" "master" {
  name = "${var.name}-master"
  role = "${aws_iam_role.master.id}"

  policy = "${data.aws_iam_policy_document.master-instance-kubernetes-operations.json}"
}

data "aws_iam_policy_document" "master-ssm" {
  // Give masters the ability to do CRUD on gravity tokens
  statement {
    actions = [
      "ssm:DescribeParameters",
      "ssm:GetParameters",
      "ssm:GetParameter",
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:GetParametersByPath",
    ]

    resources = [
      "${local.arn_prefix}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/telekube/${var.name}/*",
    ]
  }

  // fetch KMS decrypt key
  statement {
    actions = ["kms:Decrypt"]

    resources = [
      "${data.aws_kms_alias.ssm.target_key_arn}",
    ]
  }
}

resource "aws_iam_role_policy" "master_ssm" {
  name   = "${var.name}-master-ssm"
  role   = "${aws_iam_role.master.id}"
  policy = "${data.aws_iam_policy_document.master-ssm.json}"
}

data "aws_iam_policy_document" "master-lifecycle-hooks" {
  statement {
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
    ]

    resources = [
      "${aws_sqs_queue.lifecycle_hooks.arn}",
    ]
  }
}

resource "aws_iam_role_policy" "master_lifecycle_hooks" {
  name   = "${var.name}-master-lifecycle-hooks"
  role   = "${aws_iam_role.master.id}"
  policy = "${data.aws_iam_policy_document.master-lifecycle-hooks.json}"
}

data "aws_iam_policy_document" "worker-instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "worker" {
  name               = "${var.name}-worker"
  tags               = "${merge(local.common_tags, map())}"
  assume_role_policy = "${data.aws_iam_policy_document.worker-instance-assume-role-policy.json}"
}

data "aws_iam_policy_document" "worker-instance-kubernetes-operations" {
  // Manage EC2 operations
  statement {
    actions = [
      "ec2:Describe*",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
    ]

    resources = ["*"]
  }

  // Workers can manage routes for themselves
  statement {
    actions = [
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:ReplaceRoute",
    ]

    resources = ["*"]
  }

  // Workers can do read-only ECR operations
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:BatchGetImage",
    ]

    resources = ["*"]
  }

  // Workers can describe LBs
  statement {
    actions   = ["elasticloadbalancing:DescribeLoadBalancers"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "worker" {
  name   = "${var.name}-worker"
  role   = "${aws_iam_role.worker.id}"
  policy = "${data.aws_iam_policy_document.worker-instance-kubernetes-operations.json}"
}

data "aws_iam_policy_document" "worker-ssm" {
  // Give workers the ability to fetch on gravity tokens
  statement {
    actions = [
      "ssm:DescribeParameters",
      "ssm:GetParameters",
      "ssm:GetParameter",
      "ssm:GetParametersByPath",
    ]

    resources = [
      "${local.arn_prefix}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/telekube/${var.name}/*",
    ]
  }

  // fetch KMS decrypt key
  statement {
    actions = ["kms:Decrypt"]

    resources = [
      "${data.aws_kms_alias.ssm.target_key_arn}",
    ]
  }
}

// Give workers the ability to fetch the gravity tokens and decrypt key
resource "aws_iam_role_policy" "worker_ssm" {
  name   = "${var.name}-worker-ssm"
  role   = "${aws_iam_role.worker.id}"
  policy = "${data.aws_iam_policy_document.worker-ssm.json}"
}
