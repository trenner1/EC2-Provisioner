#!/bin/bash

# Determine the root directory of the script
ROOT_DIR=$(dirname "$(readlink -f "$0")")

# Set paths for Terraform and Ansible directories
TF_DIR="$ROOT_DIR/terraform"
ANSIBLE_DIR="$ROOT_DIR/ansible"
PEM_FILE="AWSEC2.pem"

# Ensure an action argument is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <apply|destroy>"
  exit 1
fi

ACTION="$1"

# Ensure Terraform directory exists and contains configurations
if [ ! -d "$TF_DIR" ] || [ ! -f "$TF_DIR/main.tf" ]; then
  echo "Error: Terraform configuration files are missing in $TF_DIR."
  exit 1
fi

# Check the action and execute accordingly
if [ "$ACTION" == "apply" ]; then
  # Step 1: Run Terraform apply
  echo "Provisioning infrastructure with Terraform..."
  cd "$TF_DIR" || exit
  terraform apply -auto-approve || { echo "Terraform apply failed"; exit 1; }

  # Step 2: Fetch the public IP from Terraform output
echo "Fetching instance public IP..."
INSTANCE_IP=$(terraform output -raw instance_ip_addr 2>/dev/null)
if [ -z "$INSTANCE_IP" ]; then
  echo "Error: Failed to fetch instance public IP."
  exit 1
fi

# Generate the AWS hostname
AWS_HOSTNAME="ec2-${INSTANCE_IP//./-}.us-west-2.compute.amazonaws.com"

# Construct the formatted SSH command
SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i \"$PEM_FILE\" ubuntu@$AWS_HOSTNAME"

  # Ensure Ansible directory exists and playbook is present
  if [ ! -d "$ANSIBLE_DIR" ] || [ ! -f "$ANSIBLE_DIR/playbook.yml" ]; then
    echo "Error: Ansible playbook or directory is missing in $ANSIBLE_DIR."
    exit 1
  fi

  # Step 3: Generate Ansible inventory
  echo "Creating Ansible inventory..."
  cd "$ANSIBLE_DIR" || exit
  cat > inventory <<EOF
[ec2]
$INSTANCE_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/$PEM_FILE
EOF

  # Step 4: Run Ansible playbook
  echo "Running Ansible playbook..."
  ansible-playbook -i inventory playbook.yml || { echo "Ansible playbook failed"; exit 1; }

  # Step 5: Output the formatted SSH command
  echo "To connect to your instance using SSH, use the following command:"
  echo "$SSH_COMMAND"

  # Step 6: Clean up (optional)
  echo "Cleaning up..."
  rm -f inventory

elif [ "$ACTION" == "destroy" ]; then
  # Step 1: Run Terraform destroy
  echo "Destroying infrastructure with Terraform..."
  cd "$TF_DIR" || exit
  terraform destroy -auto-approve || { echo "Terraform destroy failed"; exit 1; }

else
  echo "Invalid action: $ACTION"
  echo "Usage: $0 <apply|destroy>"
  exit 1
fi
