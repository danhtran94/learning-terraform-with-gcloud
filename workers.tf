resource "google_compute_instance" "worker" {
  count        = "${var.worker_instance_count}"
  name         = "${terraform.workspace}-worker-${count.index + 1}"
  machine_type = "${var.gce_instance_size}"
  zone         = "${var.gce_region}-b"

  tags = ["swarm", "worker"]

  boot_disk {
    initialize_params {
      image = "${var.machine_image}"
      size  = "10"
    }
  }

  network_interface {
    network = "${google_compute_network.swarm.name}"

    access_config {}
  }

  metadata {
    swarm    = "worker"
    ssh-keys = "ubuntu:${file("${var.public_key_path}")}"
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  connection {
    type = "ssh"
    user = "${var.ssh_user}"
  }

  provisioner "file" {
    content     = "${data.template_file.docker_conf.rendered}"
    destination = "/tmp/docker.conf"
  }

  provisioner "file" {
    source      = "scripts/install-docker-ce.sh"
    destination = "/tmp/install-docker-ce.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo sysctl -w vm.max_map_count=262144",
      "sudo echo 'vm.max_map_count=262144' >> /etc/sysctl.conf",
      "sudo mkdir -p /etc/systemd/system/docker.service.d",
      "sudo mv /tmp/docker.conf /etc/systemd/system/docker.service.d/docker.conf",
      "sudo chmod +x /tmp/install-docker-ce.sh",
      "sudo /tmp/install-docker-ce.sh ${var.docker_version}",
      "curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh",
      "sudo bash install-logging-agent.sh",
      "sudo docker swarm join --token ${data.external.swarm_tokens.result.worker} ${google_compute_instance.manager.name}:2377",
    ]
  }

  provisioner "remote-exec" {
    when = "destroy"

    inline = [
      "sudo docker swarm leave",
    ]

    on_failure = "continue"
  }

  provisioner "remote-exec" {
    when = "destroy"

    inline = [
      "sudo docker node rm --force ${self.name}",
    ]

    on_failure = "continue"

    connection {
      type = "ssh"
      user = "${var.ssh_user}"
      host = "${google_compute_instance.manager.0.network_interface.0.access_config.0.assigned_nat_ip}"
    }
  }
}
