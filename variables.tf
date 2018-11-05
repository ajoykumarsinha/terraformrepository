//  The region we will deploy our cluster into.
variable "region" {
  description = "Region to deploy the cluster into"
  #default = "us-east-1"
  default = "ap-south-1"
}

//  The public key to use for SSH access.
variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

//  This map defines which AZ to put the 'Public Subnet' in, based on the
//  region defined. You will typically not need to change this unless
//  you are running in a new region!
variable "subnetaz" {
  type = "map"

  default = {
    ap-south-1 = "ap-south-1a"
    ap-south-2 = "ap-south-1b"
  }
}
