terraform {
  required_version = "~>0.11.7"
}

provider "google" {
  version = "~> 2.5"
  project = "${var.project}"
  region  = "${var.region}"
}

resource "google_compute_project_metadata_item" "keys" {
  key     = "ssh-keys"
  value   = "ivan:${file(var.public_key_path)} \nivan1:${file(var.public_key_path)}"
  project = "${var.project}"
}

resource "google_compute_instance" "app" {
  count        = "${var.node_count}"
  name         = "app${count.index}"
  machine_type = "g1-small"
  zone         = "${var.zone}"
  tags         = ["reddit-app"]

  boot_disk {
    initialize_params {
      image = "${var.disk_image}"
    }
  }

  network_interface {
    network       = "default"
    access_config = {}
  }

  connection {
    type        = "ssh"
    user        = "ivan"
    agent       = false
    private_key = "${file(var.private_key_path)}"
  }
}

resource "google_compute_firewall" "firewall_puma" {
  name    = "allow-puma-default"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["9292"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["reddit-app"]
}
