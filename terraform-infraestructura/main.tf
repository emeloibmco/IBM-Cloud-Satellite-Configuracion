##############################################################################
# Terraform Providers
##############################################################################
terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
      version = ">=1.19.0"
    }
  }
}
##############################################################################
# Provider
##############################################################################
# ibmcloud_api_key = var.ibmcloud_api_key
provider ibm {
    alias  = "primary"
    region = var.ibm_region
    max_retries = 20
}
##############################################################################
# VLAN
##############################################################################

resource "ibm_network_vlan" "public_vlan" {
  name            = "public_vlan"
  datacenter      = var.datacenter
  type            = "PUBLIC"
  router_hostname = "fcr01a.${var.datacenter}"
}
resource "ibm_network_vlan" "private_vlan" {
  name            = "private_vlan"
  datacenter      = var.datacenter
  type            = "PRIVATE"
  router_hostname = "bcr01a.${var.datacenter}"
}
##############################################################################
# Control plane
# ibmcloud sl hardware create-options
# OS_RHEL_8_X_64_BIT_PER_PROCESSOR_LICENSING      REDHAT_8_64
##############################################################################
resource "ibm_compute_vm_instance" "control_plane" {
    for_each             = { for vm in var.control_plane : vm.hostname => vm }
    domain               = "clusteropenshift.com"
    os_reference_code    = "REDHAT_8_64"
    datacenter           = var.datacenter
    hourly_billing       = true
    private_network_only = false
    network_speed        = 10
    cores                = 4
    memory               = 16384
    disks                = each.value.disks
    local_disk           = false
    hostname = each.value.hostname
    public_vlan_id = ibm_network_vlan.public_vlan.id
    private_vlan_id = ibm_network_vlan.private_vlan.id
}

##############################################################################
# Worker nodes
##############################################################################

resource "ibm_compute_vm_instance" "worker_nodes" {
    for_each             = { for vm in var.worker_nodes : vm.hostname => vm }
    domain               = "clusteropenshift.com"
    os_reference_code    = "REDHAT_8_64"
    datacenter           = var.datacenter
    hourly_billing       = true
    private_network_only = false
    cores                = 4
    memory               = 16384
    disks                = each.value.disks
    local_disk           = false
    hostname = each.value.hostname
    public_vlan_id = ibm_network_vlan.public_vlan.id
    private_vlan_id = ibm_network_vlan.private_vlan.id
}

##############################################################################
# ODF
##############################################################################

#resource "ibm_compute_vm_instance" "ODF" {
#    for_each             = { for vm in var.ODF : vm.hostname => vm }
#    domain               = "clusteropenshift.com"
#    os_reference_code    = "REDHAT_8_64"
#    datacenter           = var.datacenter
#    hourly_billing       = true
#    private_network_only = false
#    cores                = 8
#    memory               = 32768
#    disks                = each.value.disks
#    local_disk           = false
#    hostname = each.value.hostname
#    public_vlan_id = data.ibm_network_vlan.public_vlan.id
#    private_vlan_id = data.ibm_network_vlan.private_vlan.id
#}
