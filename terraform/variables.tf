###############################################################################
# Instance Variables
###############################################################################
variable "region" {
  type        = string
  description = "The AWS Region to deploy resources to"
  default     = "us-west-2"
}

variable "availability_zone" {
  type        = string
  description = "The AZ to deploy resources to"
  default     = "us-west-2a"
}

variable "instance_type" {
  type        = string
  description = "Instance type for the EC2 Instance"
  default     = "t2.micro"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the EC2 Instance"
  default     = "ami-05d38da78ce859165"
}




###############################################################################
# Authentication Variables
###############################################################################

variable "key_name" {
  type        = string
  description = "Name of the key pair used to access the ec2 instance"
  default     = "AWSEC2"
}

variable "public_key_path" {
  type        = string
  description = "~/.ssh/AWSEC2.pem"
}


###############################################################################
# Networking and Security Variables
###############################################################################

variable "subnet_id" {
  type        = string
  description = "sthe subnet where the ec2 instance will be launched"
  default     = "subnet-09730f4b4e65b78a2"
}

variable "vpc_security_group_ids" {
  type    = list(string)
  default = ["sg-079c5ab6a7d39c4d1"]
}

###############################################################################
# EBS Variables
###############################################################################

variable "volume_size_gb" {
  type    = number
  default = 100
}

variable "ebs_volume_id" {
  type        = string
  description = "The ID of the existing ebs volume to attach to the ec2 instance"
  default     = "vol-0be9bc0fd9a38c370"
}

variable "external_device" {
  type        = string
  description = "the path name for the external volume"
  default     = "/dev/xvdh"
}