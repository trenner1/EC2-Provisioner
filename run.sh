#!/bin/bash

# Determine the root directory of the script
ROOT_DIR=$(dirname "$(readlink -f "$0")")

# Set paths for Terraform and Ansible directories
TF_DIR="$ROOT_DIR/terraform"
ANSIBLE_DIR="$ROOT_DIR/ansible"
PEM_FILE_DIR="${HOME}/.ssh/"
PEM_FILE="AWSEC2.pem"
PUB_KEY_FILE="${PEM_FILE_DIR}${PEM_FILE}.pub"
AWS_KEY_NAME="AWSEC2Key"

# Function to generate the public key from the PEM file
generate_public_key() {
  if [ ! -f "$PUB_KEY_FILE" ]; then
    echo "Generating public key from PEM file..."
    ssh-keygen -y -f "${PEM_FILE_DIR}${PEM_FILE}" > "$PUB_KEY_FILE" || {
      echo "Failed to generate public key from PEM file."
      exit 1
    }
  else
    echo "Public key already exists: $PUB_KEY_FILE"
  fi
}

# Function to check if the SSH key exists in AWS
key_exists_in_aws() {
  AWS_PAGER="" aws ec2 describe-key-pairs --key-names "$AWS_KEY_NAME" > /dev/null 2>&1
}

# Function to upload the SSH key to AWS
upload_key_to_aws() {
  if key_exists_in_aws; then
    echo "SSH key '$AWS_KEY_NAME' already exists in AWS. Skipping upload."
  else
    echo "Uploading SSH key to AWS..."
    AWS_PAGER="" aws ec2 import-key-pair --key-name "$AWS_KEY_NAME" --public-key-material fileb://"$PUB_KEY_FILE" || {
      echo "Failed to upload SSH key."
      exit 1
    }
  fi
}

# Function to remove the SSH key from AWS
remove_key_from_aws() {
  if key_exists_in_aws; then
    echo "Removing SSH key from AWS..."
    AWS_PAGER="" aws ec2 delete-key-pair --key-name "$AWS_KEY_NAME" || {
      echo "Failed to remove SSH key."
      exit 1
    }
  else
    echo "SSH key '$AWS_KEY_NAME' does not exist in AWS. Skipping removal."
  fi
}

# Ensure Terraform directory exists and contains configurations
if [ ! -d "$TF_DIR" ] || [ ! -f "$TF_DIR/main.tf" ]; then
  echo "Error: Terraform configuration files are missing in $TF_DIR."
  exit 1
fi

# Handle "destroy" operation
if [[ $1 == "destroy" ]]; then
  # Step 1: Run Terraform destroy
  echo "Destroying infrastructure with Terraform..."
  cd "$TF_DIR" || exit
  terraform destroy -auto-approve || { echo "Terraform destroy failed"; exit 1; }
  
  # Step 2: Remove the SSH key from AWS
  remove_key_from_aws
  exit 0
fi

# Handle "apply" operation
if [[ $1 == "apply" || -z $1 ]]; then
  # Step 1: Generate the public key
  generate_public_key

  # Step 2: Upload SSH key to AWS
  upload_key_to_aws

  # Step 3: Run Terraform apply
  echo "Provisioning infrastructure with Terraform..."
  cd "$TF_DIR" || exit
  terraform apply -auto-approve || { echo "Terraform apply failed"; exit 1; }

  # Step 4: Fetch the public IP from Terraform output
  echo "Fetching instance public IP..."
  INSTANCE_IP=$(terraform output -raw instance_ip_addr 2>/dev/null)
  if [ -z "$INSTANCE_IP" ]; then
    echo "Error: Failed to fetch instance public IP."
    exit 1
  fi

  # Ensure Ansible directory exists and playbook is present
  if [ ! -d "$ANSIBLE_DIR" ] || [ ! -f "$ANSIBLE_DIR/playbook.yml" ]; then
    echo "Error: Ansible playbook or directory is missing in $ANSIBLE_DIR."
    exit 1
  fi

  # Step 5: Generate Ansible inventory
  echo "Creating Ansible inventory..."
  cd "$ANSIBLE_DIR" || exit
  cat > inventory <<EOF
[ec2]
$INSTANCE_IP ansible_user=ubuntu ansible_ssh_private_key_file=${PEM_FILE_DIR}${PEM_FILE}
EOF

  # Step 6: Run Ansible playbook
  echo "Running Ansible playbook..."
  ansible-playbook -i inventory playbook.yml || { echo "Ansible playbook failed"; exit 1; }

  # Generate the AWS hostname
  AWS_HOSTNAME="ec2-${INSTANCE_IP//./-}.us-west-2.compute.amazonaws.com"

  # Construct the formatted SSH command
  SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i \"${PEM_FILE_DIR}${PEM_FILE}\" ubuntu@$AWS_HOSTNAME"

  # Step 7: Output the formatted SSH command
  echo "To connect to your instance using SSH, use the following command:"
  echo "$SSH_COMMAND"

  # Step 8: Clean up (optional)
  echo "Cleaning up..."
  rm -f inventory
fi
