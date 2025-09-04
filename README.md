# Ubuntu Cloud image for KVM!
# Features


✅ Official **Ubuntu Cloud** images (Jammy by default; easily switch to Noble or others).
    
✅ **cloud-init (NoCloud)** seeds an `ansible` user with your SSH public key.
    
✅ Works with **Packer v1.14** (HCL2) and the **qemu** builder.
    
✅ Produces a compact **qcow2** artifact for **libvirt**, **virt-install**, or **qemu-system**.
    
✅ Clean variable-driven templating — no secrets hard-coded.


# Project Layout

```hcl
packer-ubuntu-cloudimg/
├─ packer.pkr.hcl
├─ variables.pkr.hcl                 # optional (you can also use *.auto.pkrvars.hcl)
└─ cloud-init/
   ├─ user-data.tftpl                # templated by Packer (ansible_user + ssh_authorized_key)
   └─ meta-data                      # NoCloud metadata
```

# Host Requirements

-   **Linux** host with hardware virtualization (KVM) enabled.
    
-   **QEMU/KVM & libvirt**
    
    -   Ubuntu/Debian:
    ``` sh
	  sudo apt-get update
	  sudo apt-get install -y qemu-kvm libvirt-daemon-system virtinst
	  sudo usermod -aG kvm,libvirt "$USER"   # log out/in afterwards

    ```
   -   **Validate:**
   ``` sh
   ls -l /dev/kvm
   virt-host-validate

   ```
-   **Packer**: v**1.14** or newer (`packer version`)
    
-   **Ansible**: v2.12+ (only needed if you later add Ansible provisioners)
    
-   **SSH key**: a public key to inject (e.g., `~/.ssh/id_ed25519.pub`)


# Quick Start

**Set your SSH public key** (auto-loaded vars file)

Create `variables.auto.pkrvars.hcl`:
```bash
ssh_authorized_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... your@email"
ansible_user       = "ansible"   # optional; default: "ansible"
```
**Initialize & build**
```bash
cd packer-ubuntu
packer init .
packer validate .
packer build .

```
** Resulting artifact**
```bash
output/ubuntu-base/disk.qcow2
```

# How It Works (Packer v1.14 specifics)
Packer attaches a **NoCloud** seed ISO to the VM via `cd_content` and renders your variables into `cloud-init/user-data.tftpl` using `templatefile()`.
```
🔴 **Do not** set `ssh_authorized_key` inside the `source "qemu"` block — it’s **not** a builder argument and will trigger:  
`An argument named "ssh_authorized_key" is not expected here.`
```
**Key snippet (`packer.pkr.hcl`):**
```hcl
cd_label  = "cidata"
cd_content = {
  "user-data" = templatefile("${path.root}/cloud-init/user-data.tftpl", {
    ansible_user       = var.ansible_user
    ssh_authorized_key = var.ssh_authorized_key
  })
  "meta-data" = file("${path.root}/cloud-init/meta-data")
}
```
**`cloud-init/user-data.tftpl` (excerpt):**
```yaml
#cloud-config
users:
  - name: ${ansible_user}
    groups: [sudo]
    shell: /bin/bash
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - ${ssh_authorized_key}

runcmd:
  - systemctl enable --now qemu-guest-agent || true
```

# Use the Image (libvirt / qemu)
**libvirt (`virt-install`)**
```bash
virt-install \
  --name ubuntu-base-guest \
  --memory 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/ubuntu-base.qcow2,format=qcow2,bus=virtio \
  --import \
  --os-variant ubuntu22.04 \
  --network network=default,model=virtio \
  --noautoconsole
```

# Using as a base for other Packer builds
```hcl
# e.g., packer-child/variables.pkr.hcl
base_image_path = "../packer-ubuntu-cloudimg/output/ubuntu-base/disk.qcow2"

# builder
source "qemu" "child" {
  iso_url      = var.base_image_path
  iso_checksum = "none"
  disk_image   = true
  # ...
}
```

# Troubleshooting
<details> <summary><strong>Packer can’t SSH in (timeout)</strong></summary>

-   Check cloud-init logs: `/var/log/cloud-init.log`, `/var/log/cloud-init-output.log`
    
-   Ensure your **public key** in `variables.auto.pkrvars.hcl` matches the private key used by your SSH agent.
    
-   Increase `ssh_timeout` and `ssh_handshake_attempts` in the builder if your host is slow.
    

</details> <details> <summary><strong>“ssh_authorized_key is not expected here”</strong></summary>

You placed `ssh_authorized_key` inside the `source "qemu"` block.  
Remove it there — set it as a **variable**, and reference it only inside `templatefile(...)` for `cd_content`.

</details> <details> <summary><strong>KVM not available / build is slow</strong></summary>

-   Ensure virtualization is enabled in BIOS/UEFI.
    
-   Verify `/dev/kvm` exists and your user is in `kvm` and `libvirt` groups (log out/in after adding).
    

</details>

# Security Notes
-   Treat your **SSH keys** as secrets — never commit private keys.
    
-   Pin and verify the **SHA256 checksum** of the Ubuntu image for production builds. Example:
```sh
curl -sL https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS | grep server-cloudimg-amd64.img

```
-   Then set `iso_checksum` accordingly.
    
-   If you publish artifacts, scrub logs and avoid embedding sensitive info in images.

# License
Released under the **MIT License**.  
You are free to **use, copy, modify, merge, publish, distribute, sublicense, and/or sell** copies of this software.
```vbnet
MIT License

Copyright (c) 2025 <Your Name>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
...
```

⭐ **If this project helps, please star the repo and share improvements!**
