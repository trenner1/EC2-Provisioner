###############################################################################
# Instance Variables
###############################################################################
variable "region" {
  type        = string
  description = "The AWS Region to deploy resources to"
}

variable "availability_zone" {
  type        = string
  description = "The AZ to deploy resources to"
}

variable "instance_type" {
  type        = string
  description = "Instance type for the EC2 Instance"
  default     = "t2.micro"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the EC2 Instance"
}

###############################################################################
# Authentication Variables
###############################################################################
variable "key_name" {
  type        = string
  description = "Name of the key pair used to access the EC2 instance"
}

###############################################################################
# Networking and Security Variables
###############################################################################
variable "subnet_id" {
  type        = string
  description = "The subnet where the EC2 instance will be launched"
}

variable "vpc_security_group_ids" {
  type        = list(string)
  description = "List of security group IDs to associate with the instance"
}

###############################################################################
# EBS Variables
###############################################################################
variable "volume_size_gb" {
  type    = 
  description = "The size of the EBS volume in GB"
  default = 100
}

variable "ebs_volume_id" {
  type        = string
  description = "The ID of the existing EBS volume to attach to the EC2 instance"
}

variable "external_device" {
  type        = string
  description = "The path name for the external volume"
  default     = "/dev/xvdh"
}
