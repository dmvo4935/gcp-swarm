resource "google_compute_network" "my-vpc" {
  name                    = "my-vpc"
  auto_create_subnetworks = "false"
  project                 = "${var.project_name}"
}

resource "google_compute_subnetwork" "general-subnet" {
  name          = "general-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "europe-west1"
  network       = "${google_compute_network.my-vpc.self_link}"

  #    project = "eternal-centaur-185911"
  #    secondary_ip_range {
  #      range_name    = "tf-test-secondary-range-update1"
  #      ip_cidr_range = "192.168.10.0/24"
  #    }
}

resource "google_compute_subnetwork" "docker-subnet" {
  name          = "docker-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = "europe-west1"
  network       = "${google_compute_network.my-vpc.self_link}"

  #    project = "eternal-centaur-185911"
  #    secondary_ip_range {
  #      range_name    = "tf-test-secondary-range-update1"
  #      ip_cidr_range = "192.168.10.0/24"
  #    }
}

resource "google_compute_firewall" "ssh-access-external" {
  name    = "ssh-access-external"
  network = "${google_compute_network.my-vpc.name}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction     = "INGRESS"
  source_ranges = ["195.250.62.248/29"]
  target_tags   = ["master", "management"]
}

resource "google_compute_firewall" "all-access-internal" {
  name    = "all-access-internal"
  network = "${google_compute_network.my-vpc.name}"

  allow {
    protocol = "all"
  }

  direction   = "INGRESS"
  source_tags = ["management"]
}

resource "google_compute_route" "internal-default" {
  name                   = "internal-default"
  dest_range             = "0.0.0.0/0"
  network                = "${google_compute_network.my-vpc.name}"
  next_hop_instance      = "${google_compute_instance.management-instance.self_link}"
  next_hop_instance_zone = "europe-west1-b"
  priority               = 100
  tags                   = ["master", "nodes"]
}

resource "google_compute_firewall" "internet-access-internal" {
  name    = "internet-access-internal"
  network = "${google_compute_network.my-vpc.name}"

  allow {
    protocol = "all"
  }

  direction   = "INGRESS"
  source_tags = ["master", "nodes"]
}

resource "google_compute_instance_template" "docker-instance" {
  name        = "docker-instance-template"
  description = "This template is used to create docker node instances."

  tags = ["nodes"]

  labels = {
    environment = "production"
  }

  instance_description = "Docker node instance"
  machine_type         = "f1-micro"
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image = "ubuntu-1604-lts"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.docker-subnet.self_link}"

    #    access_config {
    #      network_tier = "STANDARD"
    #    }
  }

  metadata {
    ssh-keys  = "${var.management_user}:${file("${var.public_key_path}")}"
    user-data = "${data.template_cloudinit_config.node_config.rendered}"
    role      = "swarm_nodes"
  }

  metadata_startup_script = "${data.template_file.worker_init.rendered}"
}

resource "google_compute_instance_group_manager" "docker-instances" {
  name = "docker-instances"

  base_instance_name = "docker-node"
  instance_template  = "${google_compute_instance_template.docker-instance.self_link}"
  update_strategy    = "NONE"
  zone               = "europe-west1-b"
  depends_on         = ["google_compute_instance.master-instance", "google_compute_instance_template.docker-instance"]

  #  target_pools = ["${google_compute_target_pool.docker-instances.self_link}"]
  target_size = 2

  #  named_port {
  #    name = "customHTTP"
  #    port = 8888
  #  }

  #  auto_healing_policies {
  #    health_check      = "${google_compute_health_check.autohealing.self_link}"
  #    initial_delay_sec = 300
  #  }
}

resource "google_compute_instance" "master-instance" {
  name           = "docker-master"
  machine_type   = "f1-micro"
  zone           = "europe-west1-b"
  can_ip_forward = "true"

  network_interface {
    subnetwork = "${google_compute_subnetwork.docker-subnet.self_link}"

    access_config {
      network_tier = "STANDARD"
    }
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-1604-lts"
    }
  }

  tags = ["master"]

  metadata {
    ssh-keys = "${var.management_user}:${file("${var.public_key_path}")}"
    ssh_user = "${var.management_user}"
    role     = "swarm_mgr"
    routable = "false"
  }

  #metadata_startup_script = "${data.template_cloudinit_config.master_config.rendered}"

  #  service_account {
  #    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  #  }
}

resource "google_compute_instance" "management-instance" {
  name           = "management-node"
  machine_type   = "f1-micro"
  zone           = "europe-west1-b"
  can_ip_forward = "true"

  network_interface {
    subnetwork = "${google_compute_subnetwork.general-subnet.self_link}"

    access_config {
      network_tier = "STANDARD"
    }
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-1604-lts"
    }
  }

  tags = ["management"]

  metadata {
    ssh-keys = "${var.management_user}:${file("${var.public_key_path}")}"
    ssh_user = "${var.management_user}"
    role     = "management_node"
  }

  provisioner "file" {
    source      = "${var.private_key_path}"
    destination = "~/.ssh/${var.private_key_path}"

    connection {
      type        = "ssh"
      user        = "${var.management_user}"
      private_key = "${file("${var.private_key_path}")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod go=--- ~/.ssh/${var.private_key_path}",
      "sudo sysctl -w net.ipv4.ip_forward=1",
      "echo net.ipv4.ip_forward=1 | sudo tee /etc/sysctl.d/99_ip_forward.conf",
      "sudo iptables -t nat -A POSTROUTING -o + -j MASQUERADE",
    ]

    connection {
      type        = "ssh"
      user        = "${var.management_user}"
      private_key = "${file("${var.private_key_path}")}"
    }
  }

  #  service_account {
  #    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  #  }
}

data "template_file" "worker_init" {
  template = "${file("init_script.sh")}"

  vars {
    master_address = "${google_compute_instance.master-instance.network_interface.0.address}"
  }
}

###################################################
# Templates not working                           #
#                                                 #
###################################################
data "template_file" "nodes_init" {
  template = "${file("nodes_init.tpl")}"
}

data "template_file" "master_init" {
  template = "${file("master_init.tpl")}"
}

data "template_cloudinit_config" "node_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.nodes_init.rendered}"
  }
}

data "template_cloudinit_config" "master_config" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.master_init.rendered}"
  }
}
