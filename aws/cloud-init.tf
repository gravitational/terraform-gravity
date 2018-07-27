//
// Cloud-init scripts
//

// Common cloud-init configuration for all nodes
data "template_file" "common-config" {
  template = "${file("${path.module}/cloud-init/common.config.tpl")}"

  vars {
    cluster_name         = "${var.name}"
    gravity_version      = "${var.gravity_version}"
    source               = "${var.dl_url}"
    ops_url              = "${var.ops_url}"
    ops_token            = "${var.ops_token}"
    flavor               = "${var.flavor}"
    master_role          = "${var.master_role}"
    worker_role          = "${var.worker_role}"
    ops_advertise_addr   = "${var.ops_advertise_addr}"
    aws_hosted_zone_name = "${var.aws_hosted_zone_name}"
    email                = "${var.email}"
    skip_install         = "${var.skip_install}"
  }
}

// Common script file to be executed on all nodes
data "template_file" "common-script" {
  template = "${file("${path.module}/cloud-init/common.script.tpl")}"

  vars {
    cluster_name         = "${var.name}"
    gravity_version      = "${var.gravity_version}"
    source               = "${var.dl_url}"
    ops_url              = "${var.ops_url}"
    ops_token            = "${var.ops_token}"
    flavor               = "${var.flavor}"
    master_role          = "${var.master_role}"
    worker_role          = "${var.worker_role}"
    ops_advertise_addr   = "${var.ops_advertise_addr}"
    aws_hosted_zone_name = "${var.aws_hosted_zone_name}"
    email                = "${var.email}"
    skip_install         = "${var.skip_install}"
  }
}

// Shell script for bootstrapping master nodes
data "template_file" "master" {
  template = "${file("${path.module}/cloud-init/master.script.tpl")}"

  vars {
    cluster_name         = "${var.name}"
    gravity_version      = "${var.gravity_version}"
    source               = "${var.dl_url}"
    ops_url              = "${var.ops_url}"
    ops_token            = "${var.ops_token}"
    flavor               = "${var.flavor}"
    master_role          = "${var.master_role}"
    worker_role          = "${var.worker_role}"
    ops_advertise_addr   = "${var.ops_advertise_addr}"
    aws_hosted_zone_name = "${var.aws_hosted_zone_name}"
    email                = "${var.email}"
    skip_install         = "${var.skip_install}"

    // OIDC variables
    oidc_client_id     = "${var.oidc_client_id}"
    oidc_client_secret = "${var.oidc_client_secret}"
    oidc_claim         = "${var.oidc_claim}"
    oidc_issuer_url    = "${var.oidc_issuer_url}"
  }
}

// Shell script for bootstrapping worker nodes
data "template_file" "worker" {
  template = "${file("${path.module}/cloud-init/worker.script.tpl")}"

  vars {
    cluster_name         = "${var.name}"
    gravity_version      = "${var.gravity_version}"
    source               = "${var.dl_url}"
    ops_url              = "${var.ops_url}"
    ops_token            = "${var.ops_token}"
    flavor               = "${var.flavor}"
    master_role          = "${var.master_role}"
    worker_role          = "${var.worker_role}"
    ops_advertise_addr   = "${var.ops_advertise_addr}"
    aws_hosted_zone_name = "${var.aws_hosted_zone_name}"
    email                = "${var.email}"
    skip_install         = "${var.skip_install}"

    // OIDC variables
    oidc_client_id     = "${var.oidc_client_id}"
    oidc_client_secret = "${var.oidc_client_secret}"
    oidc_claim         = "${var.oidc_claim}"
    oidc_issuer_url    = "${var.oidc_issuer_url}"
  }
}

# Render a multi-part cloudinit config making use of the part
# above, and other source files
data "template_cloudinit_config" "master" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.common-config.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.common-script.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.master.rendered}"
  }
}

data "template_cloudinit_config" "worker" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.common-config.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.common-script.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.worker.rendered}"
  }
}
