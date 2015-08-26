# Terraform currently only has limited support for reading environment variables
# Variables for use with terraform must be prefexed with 'TF_VAR_'
# These two variables are passed in as environment variables named:
# TF_VAR_AWS_ACCESS_KEY_ID and TF_VAR_AWS_SECRET_ACCESS_KEY respectively
variable "AWS_ACCESS_KEY_ID" {}
variable "AWS_SECRET_ACCESS_KEY" {}

resource "template_file" "manifest" {
    filename = "${path.module}/manifest.yml.tpl"

    vars {
        aws_static_ip    =  "${var.microbosh_IP}"
        aws_subnet_id    =  "${aws_subnet.bastion.0.id}"
        aws_availability_zone = "${var.zones.zone0}"
        aws_secret_access_key = "${var.AWS_SECRET_ACCESS_KEY}"
        aws_access_key_id = "${var.AWS_ACCESS_KEY_ID}"
        aws_region       = "${var.region}"
        bosh_security_group = "${var.env}-cf-microbosh"
    }
}

resource "aws_instance" "bastion" {
  ami = "${lookup(var.amis, var.region)}"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.bastion.0.id}"
  private_ip = "10.0.0.4"
  vpc_security_group_ids = ["${aws_security_group.bastion.id}"]
  key_name = "${var.key_pair_name}"
  source_dest_check = false

  root_block_device = {
    volume_type = "gp2"
    volume_size = 100
  }

  tags = {
    Name = "${var.env}-bastion"
  }
  connection {
    user = "ubuntu"
    key_file = "ssh/insecure-deployer"
  }

  provisioner "remote-exec" {
        inline = ["cat << EOF > /home/ubuntu/manifest_aws.yml",
         "${template_file.manifest.rendered}",
         "EOF"]
  }

  provisioner "file" {
          source = "${path.module}/ssh/insecure-deployer"
          destination = "/home/ubuntu/.ssh/id_rsa"
  }

  provisioner "file" {
          source = "${path.module}/ssh/insecure-deployer.pub"
          destination = "/home/ubuntu/.ssh/id_rsa.pub"
  }

  provisioner "file" {
      source = "${path.module}/provision.sh"
      destination = "/home/ubuntu/provision.sh"
  }
}

