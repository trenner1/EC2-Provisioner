###############################################################################
# PROVIDER
###############################################################################
provider "aws" {
  region = var.region
}

###############################################################################
# FETCH PUBLIC IP FOR SSH ACCESS
###############################################################################

# Primary IP fetching service
data "http" "primary_ip" {
  url = "https://checkip.amazonaws.com"
}

# Fallback IP fetching service
data "http" "fallback_ip" {
  url = "https://api.ipify.org"
}

# Determine which IP to use
locals {
  ssh_ip = contains([200], data.http.primary_ip.status_code) ? chomp(data.http.primary_ip.response_body) : chomp(data.http.fallback_ip.response_body)
}


###############################################################################
# SECURITY GROUP
###############################################################################

resource "aws_security_group" "dev_instance_sg" {
  name        = "dev_instance_sg"
  description = "Allow SSH access from the fetched IP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${local.ssh_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DevMachineSG"
  }
}

###############################################################################
# CREATE INSTANCE
###############################################################################
resource "aws_instance" "dev_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.dev_instance_sg.id]

  root_block_device {
    delete_on_termination = true # Allow root volume to be ephemeral
  }

  user_data = <<-EOF
  #!/bin/bash
  sudo apt-get update -y
  sudo apt-get install -y xfsprogs

  # Create a directory for mounting
  sudo mkdir -p /data

  # Check if the volume has a filesystem and format it if needed
  if ! file -s /dev/xvdh | grep -q "XFS"; then
      sudo mkfs -t xfs /dev/xvdh
  fi

  # Mount the volume
  sudo mount /dev/xvdh /data

  # Add to /etc/fstab for automatic mounting on reboot
  echo '/dev/xvdh /data xfs defaults 0 0' | sudo tee -a /etc/fstab
EOF

  tags = {
    Name = "DevMachine"
  }
}

###############################################################################
# ATTACH PERSISTENT VOLUME TO INSTANCE
###############################################################################

resource "aws_volume_attachment" "data_volume_attach" {
  device_name = var.external_device
  volume_id   = var.ebs_volume_id
  instance_id = aws_instance.dev_instance.id

  # Ensure clean detachment
  force_detach = true
}

output "instance_ip_addr" {
  value = aws_instance.dev_instance.public_ip
}

output "ssh_ip" {
  value = local.ssh_ip
}

# output "internal_ip_addr" {
#   value = aws_security_group.dev_instance_sg.ingress.cidr_blocks
# }

