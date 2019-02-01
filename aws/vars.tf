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

variable "availability_zones" {
  description = "List of availability_zones to spread the provided subnets"
  type        = "list"
}

variable "subnets" {
  description = "A list of subnet id's to use for the cluster"
  type        = "list"
}

variable "master_security_group" {
  description = "Security group to assign master nodes"
  type        = "list"
}

variable "worker_security_group" {
  description = "Security group to assign master nodes"
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

variable "ebs_encryption" {
  description = "EBS encryption"
  default     = false
}

variable "worker_ebs_volume_size" {
  description = "The size of /var/lib/gravity on worker nodes in gigabytes"
  default     = 500
}

variable "worker_ebs_iops" {
  description = "The amount of provisioned IOPS for /var/lib/gravity on worker nodes"
  default     = 1500
}

variable "master_role" {
  description = "The master node role to install as"
  default     = "node"
}

variable "worker_role" {
  description = "The worker node role to install as"
  default     = "knode"
}

variable "associate_public_ip_address" {
  description = "Associate public IP to launched instances"
  default     = false
}

// AWS KMS alias used for encryption/decryption
// default is alias used in SSM
variable "kms_alias_name" {
  default = "alias/aws/ssm"
}

variable "gravity_version" {
  description = "Version of gravity tools to use"
  default     = "latest"
}

variable "dl_url" {
  description = "The location of the gravity application to install"
  default     = "opscenter"
}

variable "ops_url" {
  description = "The location of an existing ops center to pull the installer from"
  default     = ""
}

variable "ops_token" {
  description = "The ops center token to use for a custom ops center to get the installer"
  default     = ""
}

variable "flavor" {
  description = "The gravity application flavor to install"
  default     = "standalone"
}

variable "ops_advertise_addr" {
  description = "Only used for opscenter installation, the address:port that the ops center will be available on"
  default     = ""
}

variable "aws_hosted_zone_name" {
  description = "Temporary: the name of the route53 zone to add DNS records to for this cluster"
  default     = ""
}

variable "email" {
  description = "Email address to use when registering letsencrypt certs"
  default     = ""
}

variable "skip_install" {
  description = "Provision the servers, but skip running installation scripts"
  default     = "false"
}

//
// OIDC variables for configuraing an identity provider on install
//
variable "oidc_client_id" {
  description = ""
  default     = ""
}

variable "oidc_client_secret" {
  description = ""
  default     = ""
}

variable "oidc_claim" {
  description = ""
  default     = ""
}

variable "oidc_issuer_url" {
  description = ""
  default     = ""
}

//
// Join this cluster to a trusted cluster
//
variable "trusted_cluster_token" {
  description = "TODO(knisbet)"
  default     = ""
}

variable "trusted_cluster_host" {
  description = "TODO(knisbet)"
  default     = ""
}

// safe cluster name to use in places sensitive to naming, e.g. SQS queues and lifecycle hooks
locals {
  safe_name  = "${replace(var.name, "/[^a-zA-Z0-9\\-]/", "")}"
  arn_prefix = "arn:${element(split(":", data.aws_caller_identity.current.arn), 1)}"

  common_tags = {
    "Name"                              = "${var.name}"
    "KubernetesCluster"                 = "${var.name}"
    "kubernetes.io/cluster/${var.name}" = "owned"
    Terraform                           = "true"
  }

  merged_tags = "${merge(local.common_tags, var.tags)}"
}

// Create ASG tag setup from common tags
resource "null_resource" "asg_tags" {
  count = "${length(local.merged_tags)}"

  triggers {
    key                 = "${element(keys(local.merged_tags), count.index)}"
    value               = "${element(values(local.merged_tags), count.index)}"
    propagate_at_launch = true
  }
}

locals {
  asg_tags = ["${null_resource.asg_tags.*.triggers}"]
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
