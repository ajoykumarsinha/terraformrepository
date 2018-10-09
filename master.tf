//  Launch configuration for the master


# Define an Amazon Linux AMI.
data "aws_ami" "amazonlinux" {
  most_recent = true

  owners = ["137112412989"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*"]
  }
}

resource "aws_key_pair" "openshift" {
  key_name   = "openshift"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSy1exaHf3hAlXku9ggZWWQ8cvmwGpXiYrL30XUHOUeF7Kv1OBykiAV3T8dPbV+wH5VTEcsnmBH7eLwA4gEMaHRyj1925PDy8ffySM82D1WUwbNvyoTZSxHEvRLzAfRDH/ud9xyYyeG5axA+QUs/rxMgrSCd/DT4dsbWNekYhY/nqshpPjDOmReiM7sTzrHv8QD8XuthAaICONDl6dG6gv12GWrBaga5KoMrq7WUVRrJpzigI+K/4Venfi0XsC8OzW32DIqCmkLycZS+PrwSxZDicnUU4anC0SywCB2qEIWMo6Hn+LId2uOAbB/eEQ3t8HqBwf85T8yuOB76PTkZVJ a602276@MC0A1CJC"
}

resource "aws_instance" "master" {
  ami                  = "${data.aws_ami.amazonlinux.id}"
  # Master nodes require at least 16GB of memory.
  instance_type        = "m4.xlarge"
  subnet_id            = "${aws_subnet.public-subnet.id}"
  //iam_instance_profile = "${aws_iam_instance_profile.openshift-instance-profile.id}"
  //user_data            = "${data.template_file.setup-master.rendered}"

  vpc_security_group_ids = [
    "${aws_security_group.openshift-vpc.id}",
    "${aws_security_group.openshift-public-ingress.id}",
    "${aws_security_group.openshift-public-egress.id}",
  ]

  //  We need at least 30GB for OpenShift, let's be greedy...
  root_block_device {
    volume_size = 50
  }

  # Storage for Docker, see:
  # https://docs.openshift.org/latest/install_config/install/host_preparation.html#configuring-docker-storage
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_size = 80
  }

  key_name = "${var.key_name}"

  tags {
    Name    = "${var.name_tag_prefix} Master"
    Project = "openshift"
    owner = "${var.owner}"
    TTL = "${var.ttl}"
  }
}