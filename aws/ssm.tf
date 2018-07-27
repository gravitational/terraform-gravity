resource "aws_ssm_parameter" "admin_token" {
  name        = "/telekube/${var.name}/tf-admin-token"
  description = "Admin token for terraform to administer the cluster"
  type        = "SecureString"
  value       = "${random_id.secret_admin_token.hex}"
  overwrite   = true

  tags = "${local.merged_tags}"
}

//
// Trusted Cluster (Ops Center Side)
//
/*
resource "aws_ssm_parameter" "ops_join_token" {
  count       = "${var.ops_advertise_addr != "" ? 1 : 0}"
  name        = "/telekube/${var.name}/config/trusted-cluster-token"
  description = "Trusted cluster token used to join nodes to this cluster"
  type        = "SecureString"
  value       = "${random_id.secret_trusted_cluster_token.hex}"
  overwrite   = true

  tags = "${local.merged_tags}"
}
*/

//
// Trusted Cluster (Cluster Side)
//
/*
resource "aws_ssm_parameter" "trusted_cluster_token" {
  count       = "${var.trusted_cluster_token != "" ? 1 : 0}"
  name        = "/telekube/${var.name}/trusted-cluster/token"
  description = "Trusted cluster token used to join an ops center"
  type        = "SecureString"
  value       = "${var.trusted_cluster_token}"
  overwrite   = true

  tags = "${local.merged_tags}"
}

resource "aws_ssm_parameter" "trusted_cluster_host" {
  count       = "${var.trusted_cluster_host != "" ? 1 : 0}"
  name        = "/telekube/${var.name}/trusted-cluster/host"
  description = "Hostname of the trusted cluster to connect to"
  type        = "SecureString"
  value       = "${var.trusted_cluster_host}"
  overwrite   = true

  tags = "${local.merged_tags}"
}
*/

//
// Store OIDC variables in the SSM parameter store encrypted
//
resource "aws_ssm_parameter" "oidc_client_id" {
  count       = "${var.oidc_client_id != "" ? 1 : 0}"
  name        = "/telekube/${var.name}/oidc/client-id"
  description = ""
  type        = "SecureString"
  value       = "${var.oidc_client_id}"
  overwrite   = true

  tags = "${local.merged_tags}"
}

resource "aws_ssm_parameter" "oidc_client_secret" {
  count       = "${var.oidc_client_id != "" ? 1 : 0}"
  name        = "/telekube/${var.name}/oidc/client-secret"
  description = ""
  type        = "SecureString"
  value       = "${var.oidc_client_secret}"
  overwrite   = true

  tags = "${local.merged_tags}"
}

resource "aws_ssm_parameter" "oidc_claim" {
  count       = "${var.oidc_client_id != "" ? 1 : 0}"
  name        = "/telekube/${var.name}/oidc/claim"
  description = ""
  type        = "SecureString"
  value       = "${var.oidc_claim}"
  overwrite   = true

  tags = "${local.merged_tags}"
}

resource "aws_ssm_parameter" "oidc_issuer_url" {
  count       = "${var.oidc_client_id != "" ? 1 : 0}"
  name        = "/telekube/${var.name}/oidc/issuer-url"
  description = ""
  type        = "SecureString"
  value       = "${var.oidc_issuer_url}"
  overwrite   = true

  tags = "${local.merged_tags}"
}
