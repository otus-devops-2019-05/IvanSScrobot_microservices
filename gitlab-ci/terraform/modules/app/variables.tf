variable project {
  description = "Project ID"
}

variable public_key_path {
  description = "Path to the public key used for ssh access"
}

variable private_key_path {
  description = "Path to the private key used for ssh access"
}

variable app_disk_image {
  description = "Disk image for reddit app"
  default     = "ubuntu-1604-lts"
}


variable zone {
  description = "Zone"
  default     = "europe-west1-b"
}

variable node_count {
  description = "Number of VM"
  default     = 1
}

variable app_instance_name {
  description = "Name of app VM"
}