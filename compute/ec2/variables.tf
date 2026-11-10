variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to launch into, fed from network module, through the root module"
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance size"
  type        = string
}

variable "ami_id" {
  description = "The ID of the AMI which will contain the app"
  type        = string
}

variable "us_east_1a_web_subnet_id" {
  description = "The ID of the subnet to launch the instance into, to be gotten from network module through the root module"
  type        = string
}

variable "root_volume_size_gb" {
  description = "Root volume size in GB, for the OS and the application"
  type        = number
}

variable "root_volume_type" {
  description = "Type of EBS volume for root volume"
  type        = string
  default     = "gp3"
}

variable "documents_volume_az" {
  description = "AZ for the documents EBS volume. Must match the instance's AZ."
  type        = string
}

variable "documents_volume_device_name" {
  description = "Device name for the documents volume in the instance's block device mapping"
  type        = string

  # Why /dev/sdf: AWS recommends /dev/sd[f-p] for EBS data volumes. On Nitro (m5) the OS renames
  # it to /dev/nvmeXn1 anyway, so this is only the attachment request, not what the OS sees.
  default = "/dev/sdf"
}

variable "documents_volume_size_gb" {   # Supposed: >= 450gb
  description = "Size in GB of the separate EBS volume holding customer documents (proof of delivery, bills of lading, invoices)"
  type        = number
}

variable "documents_volume_type" {
  description = "Type of EBS volume for documents storage"
  type        = string
  default     = "gp3"
}

# Passed in from the network module, through the root module
variable "igw_id" {
  description = "The EC2 EIP attachment depends on the IGW in the network module" # And, outputting a whole resource exposes it unnecessarily
  type        = string
}

variable "documents_volume_snapshot_retain_counts" {
  description = "How many daily snapshots to keep"
  type = number
}