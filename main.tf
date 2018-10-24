
#  Create the OpenShift cluster using our module.
module "openshift" {
  source          = "./modules/openshift"
  region          = "${var.region}"
  #amisize         = "t2.large" //  Smallest that meets OS specs
  vpc_cidr        = "${var.vpc_cidr}"
  subnet_cidr     = "${var.subnet_cidr}"
  subnetaz        = "${var.subnetaz}"
  key_name        = "${var.key_name}"
  private_key_data = "${var.private_key_data}"
  name_tag_prefix = "${var.name_tag_prefix}"
  owner           = "${var.owner}"
  ttl             = "${var.ttl}"
}

resource "null_resource" "post-install-master" {
  provisioner "remote-exec" {
    script = "./postinstall-master.sh"
    connection {
      host = "${module.openshift.master_public_dns}"
      #host = "${master_public_dns}"
      type = "ssh"
      agent = false
      user = "ec2-user"
      private_key = "${var.private_key_data}"
      bastion_host = "${module.openshift.bastion_public_dns}"
      #bastion_host = "${bastion_public_dns}"
    }
  }
}

resource "null_resource" "post-install-node1" {
  provisioner "remote-exec" {
    script = "./postinstall-node.sh"
    connection {
      host = "${module.openshift.node1_public_dns}"
      #host = "${node1_public_dns}"
      type = "ssh"
      agent = false
      user = "ec2-user"
      private_key = "${var.private_key_data}"
      bastion_host = "${module.openshift.bastion_public_dns}"
      #bastion_host = "${bastion_public_dns}"
    }
  }
}

resource "null_resource" "get_config" {
  provisioner "remote-exec" {
    inline = [
      "scp -o StrictHostKeyChecking=no -i ~/.ssh/private-key.pem ec2-user@${module.openshift.master_public_dns}:~/.kube/config ~/config"
    ]

    /*inline = [
      "scp -o StrictHostKeyChecking=no -i ~/.ssh/private-key.pem ec2-user@${master_public_dns}:~/.kube/config ~/config"
    ]*/

    connection {
      host = "${module.openshift.bastion_public_dns}"
      #host = "${bastion_public_dns}"
      type = "ssh"
      agent = false
      user = "ec2-user"
      private_key = "${var.private_key_data}"
    }
  }

  provisioner "local-exec" {
    command = "echo \"${var.private_key_data}\" > private-key.pem"
  }

  provisioner "local-exec" {
    command = "chmod 400 private-key.pem"
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i private-key.pem  ec2-user@${module.openshift.bastion_public_dns}:~/config config"
  }

  /*provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i private-key.pem  ec2-user@${bastion_public_dns}:~/config config"
  }*/

  provisioner "local-exec" {
    command = "sed -n 4,4p config | cut -d ':' -f 2 | sed 's/ //' > ca_certificate"
  }
  provisioner "local-exec" {
    command = "sed -n 28,28p config | cut -d ':' -f 2 | sed 's/ //' > client_certificate"
  }
  provisioner "local-exec" {
    command = "sed -n 29,29p config | cut -d ':' -f 2 | sed 's/ //' > client_key"
  }

  depends_on = ["null_resource.post-install-master"]
}

resource "null_resource" "configure_k8s" {
  provisioner "file" {
    source = "vault-reviewer.yaml"
    destination = "~/vault-reviewer.yaml"
  }

  provisioner "file" {
    source = "vault-reviewer-rbac.yaml"
    destination = "~/vault-reviewer-rbac.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl create -f vault-reviewer.yaml",
      "kubectl create -f vault-reviewer-rbac.yaml",
      "kubectl get serviceaccount vault-reviewer -o yaml > vault-reviewer-service.yaml",
      "kubectl get secret $(grep \"vault-reviewer-token\" vault-reviewer-service.yaml | cut -d ':' -f 2 | sed 's/ //') -o yaml > vault-reviewer-secret.yaml",
      "sed -n 6,6p vault-reviewer-secret.yaml | cut -d ':' -f 2 | sed 's/ //' | base64 -d > vault-reviewer-token"
    ]
  }

  connection {
    host = "${module.openshift.master_public_dns}"
    #host = "${master_public_dns}"
    type = "ssh"
    agent = false
    user = "ec2-user"
    private_key = "${var.private_key_data}"
    bastion_host = "${module.openshift.bastion_public_dns}"
    #bastion_host = "${bastion_public_dns}"
  }

  depends_on = ["null_resource.get_config"]

}