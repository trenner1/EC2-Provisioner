#!/bin/bash

# ------------------------------------------------------------------
# 0) Initial Setup
# ------------------------------------------------------------------

# Determine the root directory of the script
ROOT_DIR=$(dirname "$(readlink -f "$0")")

# Set paths for Terraform and Ansible directories
TF_DIR="$ROOT_DIR/terraform"
ANSIBLE_DIR="$ROOT_DIR/ansible"

# Default paths and names
DEFAULT_PEM_DIR="${HOME}/.ssh/"
DEFAULT_KEY_NAME="AWSEC2.pem"
DEFAULT_INSTANCE_TYPE="t2.micro"


# ------------------------------------------------------------------
# 1) Function Definitions
# ------------------------------------------------------------------

# Function to check if the SSH key exists in AWS
key_exists_in_aws() {
  local KEY_NAME="$1"
  AWS_PAGER="" aws ec2 describe-key-pairs --key-names "$KEY_NAME" > /dev/null 2>&1
}

# Function to upload the SSH key to AWS
upload_key_to_aws() {
  local KEY_NAME="$1"
  local PUB_FILE_PATH="$2"

  if key_exists_in_aws "$KEY_NAME"; then
    echo "SSH key '$KEY_NAME' already exists in AWS. Skipping upload."
  else
    echo "Uploading SSH key '$KEY_NAME' to AWS..."
    AWS_PAGER="" aws ec2 import-key-pair \
      --key-name "$KEY_NAME" \
      --public-key-material "fileb://$PUB_FILE_PATH" || {
        echo "Failed to upload SSH key."
        exit 1
      }
  fi
}

# Function to remove the SSH key from AWS
remove_key_from_aws() {
  local KEY_NAME="$1"

  if key_exists_in_aws "$KEY_NAME"; then
    echo "Removing SSH key '$KEY_NAME' from AWS..."
    AWS_PAGER="" aws ec2 delete-key-pair \
      --key-name "$KEY_NAME" || {
        echo "Failed to remove SSH key."
        exit 1
      }
  else
    echo "SSH key '$KEY_NAME' does not exist in AWS. Skipping removal."
  fi
}

# Prompt for instance size
select_instance_size() {
  echo "Select EC2 instance size:"
  echo "1) t2.micro (default)"
  echo "2) t2.small"
  echo "3) t2.medium"
  echo "4) t3.micro"
  echo "5) t3.small"
  read -p "Enter your choice [1-5]: " instance_choice

  case $instance_choice in
    2) INSTANCE_TYPE="t2.small" ;;
    3) INSTANCE_TYPE="t2.medium" ;;
    4) INSTANCE_TYPE="t3.micro" ;;
    5) INSTANCE_TYPE="t3.small" ;;
    *) INSTANCE_TYPE="$DEFAULT_INSTANCE_TYPE" ;; # Default
  esac
  echo "You selected instance type: $INSTANCE_TYPE"

  # Update instance_type in terraform.tfvars
  if grep -q '^instance_type' "$TF_DIR/terraform.tfvars"; then
    sed -i.bak "s|^instance_type.*|instance_type = \"$INSTANCE_TYPE\"|" "$TF_DIR/terraform.tfvars"
  else
    echo "instance_type = \"$INSTANCE_TYPE\"" >> "$TF_DIR/terraform.tfvars"
  fi
}


# ------------------------------------------------------------------
# 2) Main Logic
# ------------------------------------------------------------------

#
# --------------------------
#   DESTROY OPERATION
# --------------------------
#
if [[ $1 == "destroy" ]]; then
  # Step 0: Prompt a warning before destroying
  echo "WARNING: You are about to destroy your infrastructure!"
  read -p "Are you sure you want to proceed? (yes/no): " confirm_destroy
  if [[ ! $confirm_destroy =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Destroy operation aborted."
    exit 1
  fi

  # Step 1: Run Terraform destroy
  echo "Destroying infrastructure with Terraform..."
  cd "$TF_DIR" || exit
  terraform destroy -auto-approve || {
    echo "Terraform destroy failed"
    exit 1
  }

  # Step 2: Retrieve the key name from terraform.tfvars
  AWS_KEY_NAME=$(awk -F= '/^key_name/ { gsub(/[ "]/, "", $2); print $2 }' "$TF_DIR/terraform.tfvars")

  # If for some reason the key_name is not found or is empty, fall back to default
  if [ -z "$AWS_KEY_NAME" ]; then
    AWS_KEY_NAME="AWSEC2Key"
    echo "Warning: Could not find key_name in terraform.tfvars; defaulting to '$AWS_KEY_NAME'"
  fi

  # Show the found key name right before prompting about removal
  echo "Found key_name '$AWS_KEY_NAME' in terraform.tfvars"

  # Step 3: Prompt whether to remove the key from AWS
  read -p "Would you like to remove the SSH key '$AWS_KEY_NAME' from AWS? (yes/no): " REMOVE_KEY
  if [[ $REMOVE_KEY =~ ^[Yy][Ee][Ss]$ ]]; then
    remove_key_from_aws "$AWS_KEY_NAME"
  else
    echo "Skipping removal of the AWS key."
  fi

  exit 0
fi


#
# --------------------------
#   APPLY OPERATION
# --------------------------
#
if [[ $1 == "apply" || -z $1 ]]; then
  #
  # (A) Prompt user for key directory and handle key generation/selection
  #
  read -p "Enter the directory containing your SSH keys (default: ${DEFAULT_PEM_DIR}): " PEM_FILE_DIR
  PEM_FILE_DIR=${PEM_FILE_DIR:-$DEFAULT_PEM_DIR}

  # Check for existing keys in the specified directory
  KEYS=($(find "$PEM_FILE_DIR" -maxdepth 1 -type f -name "*.pem"))
  if [ ${#KEYS[@]} -eq 0 ]; then
    echo "No private keys found in $PEM_FILE_DIR."
    read -p "Would you like to generate a new private key? (yes/no): " GENERATE_KEY
    if [[ $GENERATE_KEY =~ ^[Yy][Ee][Ss]$ ]]; then
      read -p "Enter a name for the new private key (default: $DEFAULT_KEY_NAME): " PEM_FILE
      PEM_FILE=${PEM_FILE:-$DEFAULT_KEY_NAME}
      PEM_PATH="${PEM_FILE_DIR}${PEM_FILE}"
      echo "Generating a new private key at $PEM_PATH..."
      ssh-keygen -t rsa -b 2048 -f "$PEM_PATH" -N "" || {
        echo "Failed to generate a new private key."
        exit 1
      }
      echo "Private key generated: $PEM_PATH"
    else
      echo "A private key is required to proceed. Exiting..."
      exit 1
    fi
  else
    echo "Available keys in $PEM_FILE_DIR:"
    for i in "${!KEYS[@]}"; do
      echo "$((i+1))) ${KEYS[i]}"
    done
    read -p "Select a private key by number (or press Enter to use default: ${DEFAULT_KEY_NAME}): " KEY_SELECTION
    if [ -n "$KEY_SELECTION" ]; then
      PEM_FILE=$(basename "${KEYS[$((KEY_SELECTION-1))]}")
    else
      PEM_FILE=$DEFAULT_KEY_NAME
    fi
    echo "You selected: ${PEM_FILE_DIR}${PEM_FILE}"
  fi

  PUB_KEY_FILE="${PEM_FILE_DIR}${PEM_FILE}.pub"

  # Generate public key if it doesn't exist
  if [ ! -f "$PUB_KEY_FILE" ]; then
    echo "Generating public key from private key..."
    ssh-keygen -y -f "${PEM_FILE_DIR}${PEM_FILE}" > "$PUB_KEY_FILE" || {
      echo "Failed to generate public key."
      exit 1
    }
    echo "Public key generated: $PUB_KEY_FILE"
  fi

  #
  # (B) Retrieve the key name from terraform.tfvars (or use default if not found)
  #
  AWS_KEY_NAME=$(awk -F= '/^key_name/ { gsub(/[ "]/, "", $2); print $2 }' "$TF_DIR/terraform.tfvars")
  if [ -z "$AWS_KEY_NAME" ]; then
    AWS_KEY_NAME="AWSEC2Key"
    echo "Warning: Could not find key_name in terraform.tfvars; defaulting to '$AWS_KEY_NAME'"
  else
    echo "Using key_name '$AWS_KEY_NAME' from terraform.tfvars"
  fi

  # Step 1: Upload SSH key to AWS
  upload_key_to_aws "$AWS_KEY_NAME" "$PUB_KEY_FILE"

  # Step 2: Prompt for instance size
  select_instance_size

  # Step 3: Run Terraform apply
  echo "Provisioning infrastructure with Terraform..."
  cd "$TF_DIR" || exit
  terraform apply -auto-approve || {
    echo "Terraform apply failed"
    exit 1
  }

  # Step 4: Fetch the public IP from Terraform output
  echo "Fetching instance public IP..."
  INSTANCE_IP=$(terraform output -raw instance_ip_addr 2>/dev/null)
  if [ -z "$INSTANCE_IP" ]; then
    echo "Error: Failed to fetch instance public IP."
    exit 1
  fi

  #
  # (C) Verify Ansible playbook presence & run it
  #
  if [ ! -d "$ANSIBLE_DIR" ] || [ ! -f "$ANSIBLE_DIR/playbook.yml" ]; then
    echo "Error: Ansible playbook or directory is missing in $ANSIBLE_DIR."
    exit 1
  fi

  # Step 5: Generate Ansible inventory
  echo "Creating Ansible inventory..."
  cd "$ANSIBLE_DIR" || exit
  cat > inventory <<EOF
[ec2]
$INSTANCE_IP ansible_user=ubuntu ansible_ssh_private_key_file=${PEM_FILE_DIR}${PEM_FILE} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

  # Step 6: Run Ansible playbook
  echo "Running Ansible playbook..."
  ansible-playbook -i inventory playbook.yml || {
    echo "Ansible playbook failed"
    exit 1
  }

  # Generate the AWS hostname
  AWS_HOSTNAME="ec2-${INSTANCE_IP//./-}.us-west-2.compute.amazonaws.com"

  # Construct the formatted SSH command
  SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i \"${PEM_FILE_DIR}${PEM_FILE}\" ubuntu@${AWS_HOSTNAME}"

  # Step 7: Output the formatted SSH command
  echo "To connect to your instance using SSH, use the following command:"
  echo "$SSH_COMMAND"

  # Step 8: Clean up
  echo "Cleaning up..."
  rm -f inventory
fi
