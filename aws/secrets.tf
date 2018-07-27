// Generate a secret, that can then later be used for configuring the cluster
resource "random_id" "secret_admin_token" {
  byte_length = 32
}

// If this is an ops center, generate a secret in terraform for trusted clusters
// to get created automatically during installation
resource "random_id" "secret_trusted_cluster_token" {
  byte_length = 32
}
