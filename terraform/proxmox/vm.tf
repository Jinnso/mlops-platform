resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "ubuntu-24.04-cloudimg.img"
  overwrite    = false
}

resource "proxmox_virtual_environment_file" "cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      hostname     = var.vm_name
      ip_address   = "${var.vm_ip}/24"
      gateway      = var.vm_gateway
      dns_nameservers = "1.1.1.1 8.8.8.8"
      ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_file)))
    })
    file_name = "mlops-k3s-cloud-init.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "mlops_k3s" {
  name        = var.vm_name
  description = "MLOps K3s single-node cluster"
  node_name   = var.proxmox_node
  vm_id       = var.vm_id

  on_boot  = true
  started  = true

  cpu {
    cores = var.vm_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.vm_memory_mb
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = var.storage_pool
    file_id      = proxmox_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = var.vm_disk_size_gb
    discard      = "on"
    iothread     = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.vm_ip}/24"
        gateway = var.vm_gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
  }

  network_device {
    bridge = var.network_bridge
  }

  serial_device {}

  vga {
    type = "serial0"
  }

  lifecycle {
    ignore_changes = [
      initialization,
      disk[0].file_id,
    ]
  }
}

output "vm_ip" {
  value       = var.vm_ip
  description = "IP address of the K3s VM"
}

output "vm_name" {
  value       = var.vm_name
  description = "Name of the VM"
}

output "ssh_command" {
  value       = "ssh ubuntu@${var.vm_ip}"
  description = "SSH command to connect to the VM"
}
