resource "google_compute_instance" "bastion" {
  name = "${var.env}-cf-bastion"
  depends_on = [ "google_compute_firewall.ssh" ]
  machine_type = "g1-small"
  zone = "${lookup(var.zones, concat("zone", count.index))}"
  disk {
    image = "${var.os_image}"
    size  = 100 // GB
  }
  network_interface {
    network = "${google_compute_network.bastion.name}"
    access_config {}
  }
  metadata {
    sshKeys = "${var.user}:${file("${var.ssh_key_path}")}"
  }
  can_ip_forward = true
  connection {
    user = "${var.ssh_user}"
    key_file = "ssh/insecure-deployer"
  }
  tags = [ "bastion" ]

  provisioner "file" {
    source = "${path.module}/ssh/insecure-deployer"
    destination = "/home/ubuntu/.ssh/id_rsa"
  }

  provisioner "file" {
    source = "${path.module}/ssh/insecure-deployer.pub"
    destination = "/home/ubuntu/.ssh/id_rsa.pub"
  }

  provisioner "file" {
    source = "${path.module}/account.json"
    destination = "/home/ubuntu/account.json"
  }

  provisioner "remote-exec" {
    inline = [
      "chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa",
      "chmod 400 /home/ubuntu/.ssh/id_rsa"
    ]
  }

  provisioner "remote-exec" {
    script = "../scripts/setup-nat-routing.sh"
  }

}
