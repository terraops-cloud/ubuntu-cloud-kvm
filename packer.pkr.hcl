packer {
  required_version = ">= 1.9.0"

  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.0.9"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}
variable "image_version" {
  type = string
}

variable "ubuntu_cloud_image_url" {
  type        = string
  description = "URL of Ubuntu cloud image (qcow2)."
  default     = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

variable "ansible_user" {
  type        = string
  description = "User created via cloud-init for SSH/Ansible."
  default     = "ansible"
}

variable "ssh_authorized_key" {
  type        = string
  description = "SSH public key that cloud-init should authorize for the ansible user."
}

variable "vm_memory" {
  type    = number
  default = 2048
}

variable "vm_cpus" {
  type    = number
  default = 2
}

variable "disk_size_gb" {
  type    = number
  default = 10
}


locals {
  output_dir = "/opt/1TB/images/core/"
  image_name = "core-${var.image_version}.qcow2"
}

source "qemu" "ubuntu" {
  # Treat the Ubuntu cloud image as a disk we boot from.
  iso_url      = var.ubuntu_cloud_image_url
  iso_checksum = "none" # For production, pin a specific image and checksum.
  vm_name = local.image_name

  disk_image  = true
  headless    = true
  accelerator = "kvm"

  # VM resources
  memory = var.vm_memory
  cpus   = var.vm_cpus
  # Disk format and output
  format           = "qcow2"
  output_directory = local.output_dir
  qemuargs = [
    ["-cpu", "host"],
    ["-smp", "${var.vm_cpus}"],
    ["-m", "${var.vm_memory}"],
  ]

  # Attach a NoCloud seed ISO for cloud-init
  cd_label = "cidata"
  cd_content = {
    "user-data" = templatefile("${path.root}/cloud-init/user-data.tftpl", {
      ansible_user       = var.ansible_user,
      ssh_authorized_key = var.ssh_authorized_key
    })
    "meta-data" = file("${path.root}/cloud-init/meta-data")
  }

  # Packer will wait for this SSH to come up (cloud-init creates the user).
  ssh_username           = var.ansible_user
  ssh_timeout            = "20m"
  ssh_handshake_attempts = 60
  # Use your agent or a private key matching the authorized public key.
  ssh_agent_auth = true

  shutdown_command = "sudo systemctl poweroff"
}

build {
  name    = "core-${var.image_version}"
  sources = ["source.qemu.ubuntu"]

  # Run Ansible from the host over SSH
  provisioner "ansible" {
    playbook_file = "ansible/playbook.yml"
    user          = var.ansible_user
    # Ubuntu has python3 preinstalled on cloud images; be explicit just in case.
    extra_arguments = [
      "-e", "ansible_python_interpreter=/usr/bin/python3"
    ]
  }

  # Optional: compact the qcow2 image after provisioning
  # (guest must be shut down, so we do shell-local post processing)
  post-processor "shell-local" {
    inline = [
      "echo 'Final artifact located in ${local.output_dir}'"
    ]
  }
}

