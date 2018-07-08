resource "google_compute_instance_template" "worker" {
  name_prefix  = "swarm-worker-"
  project      = "${var.gce_project}"
  region       = "${var.gce_region}"
  tags         = ["worker-instance-template", "swarm", "worker"]
  machine_type = "${var.gce_instance_size}"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    source_image = "${var.machine_image}"
    auto_delete  = true
    boot         = true
  }

  metadata {
    swarm          = "worker"
    ssh-keys       = "ubuntu:${file("${var.public_key_path}")}"
    startup-script = "${data.template_file.worker_startup_script.rendered}"
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  network_interface {
    network = "${google_compute_network.swarm.name}"

    access_config {
      // Ephemeral IP
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = ["google_compute_instance.manager"]
}

resource "google_compute_instance_group_manager" "swarm_workers" {
  name               = "swarm-worker-group"
  instance_template  = "${google_compute_instance_template.worker.self_link}"
  base_instance_name = "swarm-worker"
  zone               = "${var.gce_region}-b"
  target_size        = "${var.worker_instance_count}"
}

resource "google_compute_autoscaler" "swarm_scaler" {
  name   = "swarm-worker-scaler"
  zone   = "${var.gce_region}-b"
  target = "${google_compute_instance_group_manager.swarm_workers.self_link}"

  autoscaling_policy = {
    max_replicas    = 1
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.5
    }
  }
}

resource "google_compute_backend_service" "swarm_worker" {
  name             = "swarm-worker-backend"
  port_name        = "http"
  protocol         = "HTTP"
  timeout_sec      = "10"
  session_affinity = "NONE"

  backend {
    group = "${google_compute_instance_group_manager.swarm_workers.instance_group}"
  }

  health_checks = ["${google_compute_http_health_check.swarm_worker_health.self_link}"]
}

resource "google_compute_http_health_check" "swarm_worker_health" {
  name               = "hcheck-swarm-worker"
  request_path       = "/ping"
  check_interval_sec = 1
  timeout_sec        = 1
}

resource "google_compute_url_map" "swarm_worker" {
  name            = "url-swarm-worker-map"
  default_service = "${google_compute_backend_service.swarm_worker.self_link}"
}

resource "google_compute_target_http_proxy" "swarm_worker_thprx" {
  name    = "http-swarm-sworker-proxy"
  url_map = "${google_compute_url_map.swarm_worker.self_link}"
}

resource "google_compute_global_forwarding_rule" "swarm_worker_gfr" {
  name       = "forwarding-swarm-worker-rule"
  target     = "${google_compute_target_http_proxy.swarm_worker_thprx.self_link}"
  port_range = "80"
}
