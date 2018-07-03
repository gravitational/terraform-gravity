variable name {
  description = "Name of the gravity cluster"
}

variable key_name {
  description = "AWS SSH key name to assigned to nodes"
}

variable "tags" {
  description = "Tags to add to the AWS resources"
  type        = "map"
}

variable "master_count" {
  description = "Number of master servers to provision"
  default     = "1"
}

variable "worker_count" {
  description = "Number of worker nodes to provision"
}

variable "aws_subnet_ids" {
  description = "VPC subnets to create nodes on"
  type        = "list"
}

variable "vpc_id" {
  description = "The VPC we're using"
}

variable "master_instance_type" {
  description = "AWS instance type for master nodes"
  default     = "c4.xlarge"
}

variable "worker_instance_type" {
  description = "AWS instance type for worker nodes"
  default     = "c4.xlarge"
}

variable "master_ami" {
  description = "AWS AMI to use for master nodes"
}

variable "worker_ami" {
  description = "AWS AMI to use for master nodes"
}

// AWS KMS alias used for encryption/decryption
// default is alias used in SSM
variable "kms_alias_name" {
  default = "alias/aws/ssm"
}

// safe cluster name to use in places sensitive to naming, e.g. SQS queues and lifecycle hooks
locals {
  safe_name = "${replace(var.name, "/[^a-zA-Z0-9\\-]/", "")}"

  common_tags = {
    "Name" = "${var.name}"
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
