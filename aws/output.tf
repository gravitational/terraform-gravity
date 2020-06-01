// Admin token that can be used for controlling the cluster
output "secret_admin_token" {
  value = random_id.secret_admin_token.hex
}

output "secret_trusted_cluster_token" {
  value = random_id.secret_trusted_cluster_token.hex
}
