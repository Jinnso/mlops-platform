variable "proxmox_api_url" {
  description = "Proxmox VE API URL"
  type        = string
  default     = "https://192.168.1.100:8006/api2/json"
}

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID (format: user@pam!token-name)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "vm_id" {
  description = "VM ID in Proxmox"
  type        = number
  default     = 200
}

variable "vm_name" {
  description = "VM hostname"
  type        = string
  default     = "mlops-k3s"
}

variable "vm_cpu_cores" {
  description = "Number of vCPUs"
  type        = number
  default     = 4
}

variable "vm_memory_mb" {
  description = "RAM in MB"
  type        = number
  default     = 12288
}

variable "vm_disk_size_gb" {
  description = "Disk size in GB"
  type        = number
  default     = 100
}

variable "vm_ip" {
  description = "Static IP for the VM (set in cloud-init)"
  type        = string
  default     = "192.168.1.50"
}

variable "vm_gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.1.1"
}

variable "ssh_public_key_file" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "storage_pool" {
  description = "Proxmox storage pool for VM disk"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "proxmox_ssh_password" {
  description = "Root password for SSH to Proxmox host"
  type        = string
  sensitive   = true
  default     = ""
}
