terraform {
   required_version = "~>0.11.7"
}

provider "google" {
  version = "~> 2.5"
  project = "${var.project}"
  region  = "${var.region}"
}

module "app" {
  source            = "./modules/app"
  node_count        = "${var.node_count}"
  public_key_path   = "${var.public_key_path}"
  zone              = "${var.zone}"
  app_disk_image    = "${var.app_disk_image}"
  project           = "${var.project}"
  private_key_path  = "${var.private_key_path}"
  app_instance_name = "${var.app_name}"
}
