
resource "google_compute_instance" "app" {
  count        = "${var.node_count}"  
  name         = "${var.app_instance_name}-${count.index+1}"
  machine_type = "g1-small"
  zone         = "${var.zone}"
  tags         = ["gitlab-runners"]

  boot_disk {
    initialize_params {
      image = "${var.app_disk_image}"
    }
  }

  network_interface {
    network = "default"

    access_config = {
    #  nat_ip = "${google_compute_address.app_ip.address}"
    }
  }

  metadata {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
}

#resource "google_compute_address" "app_ip" {
#  name = "reddit-app-ip"
#}
