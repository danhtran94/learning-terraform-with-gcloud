provider "google" {
  credentials = "${file("${var.gce_creds_path}")}"
  project     = "${var.gce_project}"
  region      = "${var.gce_region}"
}

resource "google_compute_network" "swarm" {
  name                    = "${terraform.workspace}-network"
  auto_create_subnetworks = true
}

data "template_file" "docker_conf" {
  template = "${file("config/docker.tpl")}"

  vars {
    ip = "${var.docker_api_ip}"
  }
}

# workaround for embeded worker token for instance_template resource using null_resouce + template_file worker_startup_script
# because external data only work correct in provisioner
resource "null_resource" "get_worker_token" {
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${var.ssh_user}@${google_compute_instance.manager.0.network_interface.0.access_config.0.assigned_nat_ip} sudo docker swarm join-token worker -q > ${path.module}/worker.token"
  }

  depends_on = ["google_compute_instance.manager"]
}

data "template_file" "worker_startup_script" {
  template = "${file("config/startup-script.tpl")}"

  vars {
    docker_api_ip  = "${var.docker_api_ip}"
    docker_version = "${var.docker_version}"
    worker_token   = "${chomp(file("${path.module}/worker.token"))}"
    manager_name   = "${google_compute_instance.manager.name}"
  }

  depends_on = ["null_resource.get_worker_token"]
}

// this external can use because it refered in a provisioner
data "external" "swarm_tokens" {
  program = ["/Users/danhtran94/terraform/src/compute_instance/scripts/fetch-tokens.sh"]

  query = {
    host = "${google_compute_instance.manager.0.network_interface.0.access_config.0.assigned_nat_ip}"
    user = "${var.ssh_user}"
  }

  depends_on = ["google_compute_instance.manager"]
}
