# Terraform-Ansible Automation with EC2 and Anaconda 🚀

## Overview

This repository automates the provisioning of an EC2 instance with Terraform and the configuration of the instance with Ansible. The setup installs Anaconda on the instance and redirects key directories to `/data` to optimize storage usage. Additionally, the script provides a quick way to tear down the infrastructure. This project is primarily used to follow along with the DataTalksClub MLOps program while keeping AWS costs low by automating the stand-up and tear-down of the infrastructure. 🌐

---

## Features ✨

- Infrastructure provisioning with Terraform
- Automated instance configuration with Ansible
- Installation of Anaconda and MLflow on the EC2 instance 🐍
- Storage optimization by redirecting directories to `/data` 📦
- Persistent `/data` volume is detached and reattached across destroy and apply cycles 🔄
- SSH access with strict host key checking disabled for convenience 🔐
- Quick teardown of resources using Terraform destroy 💥

---

## Prerequisites 📋

- AWS CLI configured initially ☁️ [Setting up the AWS CLI ](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html)
- Terraform installed locally 🛠️ [Install Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- Ansible installed locally 🤖 [How to install Ansible on MacOS](https://spacelift.io/blog/how-to-install-ansible#how-to-install-ansible-on-macos)
- SSH key pair available locally in `~/.ssh` for accessing the EC2 instance 🔑 [Create a key pair for your Amazon EC2 instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html)
- an EBS Volume created and the `ebs_volume_id` added to the varibales.tf file. Note that the ebs volume must be created in the same AZ as where you plan on launching your EC2 instance. 💾 [Create an Amazon EBS volume](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-creating-volume.html)

---

## File Structure 📂

```
.
├── ansible
│   ├── inventory         # Dynamically generated inventory file
│   ├── playbook.yml      # Ansible playbook for instance configuration
├── terraform
│   ├── main.tf           # Terraform configuration file
│   ├── variables.tf      # Terraform variables file
│   ├── terraform.tfvars  # Variable values for Terraform
├── run.sh                # Main script for automation
├── .gitignore            # Files and directories to be ignored in version control
├── README.md             # Project documentation
```

---

## Usage 📘

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd <repository-directory>
```

### Step 2: Provision Infrastructure

Run the main automation script:

```bash
./run.sh apply
```

This will:

1. Provision infrastructure using Terraform.
2. Configure the instance using Ansible.
3. Output an SSH command to access the instance.

### Step 3: Access the Instance

The script will output an SSH command like this:

```bash
ssh -o StrictHostKeyChecking=no -i "<your-key.pem>" ubuntu@ec2-<instance-id>.us-west-2.compute.amazonaws.com
```

Use this command to connect to the instance.

### Step 4: Tear Down Infrastructure

To quickly destroy the provisioned infrastructure and control costs, run:

```bash
./run.sh destroy
```

This will invoke `terraform destroy` to clean up resources. 🧹

---

## Configuration Details ⚙️

### Redirecting Directories to `/data`

- The playbook ensures that apt caches, Docker storage, and temporary directories are redirected to `/data` to optimize root volume usage.
- The `/data` volume is persistent and will be detached and reattached in subsequent destroy and apply cycles.
- Anaconda is installed in `/data/anaconda`. 🐍

### Main Items Installed via Playbook 🛠️

1. **System Packages**:

   - `python3`, `python3-pip`, `python3-venv`
   - `curl`, `wget`
   - `docker.io`

2. **Anaconda**:

   - Installed in `/data/anaconda` to manage Python environments and packages. 🐍

3. **MLflow**:

   - Installed to enable experiment tracking, model management, and deployment workflows. 📊

4. **Docker**:

   - Installed and configured with storage redirected to `/data/docker`. 🐳

5. **Storage Optimization**:
   - Apt cache redirected to `/data/apt-cache`. 🗂️
   - Temporary files redirected to `/data/tmp`. 🗄️

---

## Known Issues ⚠️

### PATH Not Updating for Anaconda

- If Anaconda's PATH does not update automatically, manually source `.bashrc` after connecting to the instance:
  ```bash
  source ~/.bashrc
  ```

---

## .gitignore 📜

```plaintext
# Terraform files
*.tfstate
*.tfstate.backup
.terraform/

# SSH keys
*.pem

# Ansible temporary files
ansible/inventory

# Logs and temporary files
*.log
*.tmp
```

---

## Notes 📝

- Ensure your AWS credentials are configured locally.
- The SSH key referenced in the Terraform and Ansible configurations must exist in `~/.ssh`. 🔑
