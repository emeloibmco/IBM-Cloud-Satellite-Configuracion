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
# security_group
##############################################################################

#Security group preestablecido
data "ibm_security_group" "sg1" {
  name = "allow_all"
}

# Usar en caso de tener permisos sobre securtiy groups en classic infraestructure
#resource "ibm_security_group" "sg1" {
#    name = "sg1"
#    description = "allow_all_outbound"
#}
#
## Allow all inbound 
#resource "ibm_security_group_rule" "sg1_inbound_tcp" {
#  security_group_id = ibm_security_group.sg1.id
#  direction = "ingress"
#  ether_type = "IPv4"
#  protocol = "tcp"
#  port_range_min = 0
#  port_range_max = 65535
#}
#
#resource "ibm_security_group_rule" "sg1_inbound_udp" {
#  security_group_id = ibm_security_group.sg1.id
#  direction = "ingress"
#  ether_type = "IPv4"
#  protocol = "udp"
#  port_range_min = 0
#  port_range_max = 65535
#}
#
#resource "ibm_security_group_rule" "sg1_inbound_icmp" {
#  security_group_id = ibm_security_group.sg1.id
#  direction = "ingress"
#  ether_type = "IPv4"
#  protocol = "icmp"
#}
#
## Allow all outbound 
#resource "ibm_security_group_rule" "sg1_outbound_tcp" {
#  security_group_id = ibm_security_group.sg1.id
#  direction = "egress"
#  ether_type = "IPv4"
#  protocol = "tcp"
#  port_range_min = 0
#  port_range_max = 65535
#}
#
#resource "ibm_security_group_rule" "sg1_outbound_udp" {
#  security_group_id = ibm_security_group.sg1.id
#  direction = "egress"
#  ether_type = "IPv4"
#  protocol = "udp"
#  port_range_min = 0
#  port_range_max = 65535
#}
#
#resource "ibm_security_group_rule" "sg1_outbound_icmp" {
#  security_group_id = ibm_security_group.sg1.id
#  direction = "egress"
#  ether_type = "IPv4"
#  protocol = "icmp"
#}
##############################################################################
# Gestión de Claves SSH
##############################################################################

# Cargar la clave pública SSH en IBM Cloud
resource "ibm_compute_ssh_key" "ssh_key" {
  label      = "terraform-ssh-key" 
  public_key = file("${path.module}/id_rsa.pub")
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
    #public_security_group_ids   = [ibm_security_group.sg1.id]
    #private_security_group_ids  = [ibm_security_group.sg1.id]
    #public_security_group_ids=[data.ibm_security_group.sg1.id]
    #private_security_group_ids=[data.ibm_security_group.sg1.id]
    ssh_key_ids          = [ibm_compute_ssh_key.ssh_key.id]

    # Copia el archivo setup_satellite.sh
    provisioner "file" {
        source      = "${path.module}/setup_satellite.sh"
        destination = "/home/setup_satellite.sh"

        connection {
            type        = "ssh"
            user        = "root"
            private_key = file("${path.module}/id_rsa")
            host        = self.ipv4_address
        }
    }

    # Copia el archivo attachHost-satellite-location.sh
    provisioner "file" {
        source      = "${path.module}/attachHost-satellite-location.sh"
        destination = "/home/attachHost-satellite-location.sh"

          connection {
            type        = "ssh"
            user        = "root"
            private_key = file("${path.module}/id_rsa")
            host        = self.ipv4_address
        }
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /home/setup_satellite.sh",
            "sudo /home/setup_satellite.sh",
            "chmod +x /home/attachHost-satellite-location.sh",
            "sleep 90",
            "sudo nohup bash /home/attachHost-satellite-location.sh",
            "echo 'Se corrieron todos los scripts' >> /home/end.log"
        ]

        connection {
            type        = "ssh"
            user        = "root"
            private_key = file("${path.module}/id_rsa")
            host        = self.ipv4_address
        }
    }
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
    network_speed        = 10
    cores                = 4
    memory               = 16384
    disks                = each.value.disks
    local_disk           = false
    hostname = each.value.hostname
    public_vlan_id = ibm_network_vlan.public_vlan.id
    private_vlan_id = ibm_network_vlan.private_vlan.id
    #public_security_group_ids   = [ibm_security_group.sg1.id]
    #private_security_group_ids  = [ibm_security_group.sg1.id]
    #public_security_group_ids=[data.ibm_security_group.sg1.id]
    #private_security_group_ids=[data.ibm_security_group.sg1.id]
    ssh_key_ids          = [ibm_compute_ssh_key.ssh_key.id]

    # Copia el archivo setup_satellite.sh
    provisioner "file" {
        source      = "${path.module}/setup_satellite.sh"
        destination = "/home/setup_satellite.sh"

        connection {
            type        = "ssh"
            user        = "root"
            private_key = file("${path.module}/id_rsa")
            host        = self.ipv4_address
        }
    }

    # Copia el archivo attachHost-satellite-location.sh
    provisioner "file" {
        source      = "${path.module}/attachHost-satellite-location.sh"
        destination = "/home/attachHost-satellite-location.sh"

          connection {
            type        = "ssh"
            user        = "root"
            private_key = file("${path.module}/id_rsa")
            host        = self.ipv4_address
        }
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /home/setup_satellite.sh",
            "sudo /home/setup_satellite.sh",
            "chmod +x /home/attachHost-satellite-location.sh",
            "sleep 90",
            "sudo nohup bash /home/attachHost-satellite-location.sh",
            "echo 'Se corrieron todos los scripts' >> /home/end.log"
        ]

        connection {
            type        = "ssh"
            user        = "root"
            private_key = file("${path.module}/id_rsa")
            host        = self.ipv4_address
        }
    }
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
#    public_vlan_id = ibm_network_vlan.public_vlan.id
#    private_vlan_id = ibm_network_vlan.private_vlan.id
#    public_security_group_ids   = [ibm_security_group.sg1.id]
#    private_security_group_ids  = [ibm_security_group.sg1.id]
#    ssh_key_ids          = [ibm_compute_ssh_key.ssh_key.id]
#
#    # Copia el archivo setup_satellite.sh
#    provisioner "file" {
#        source      = "${path.module}/setup_satellite.sh"
#        destination = "/home/setup_satellite.sh"
#
#        connection {
#            type        = "ssh"
#            user        = "root"
#            private_key = file("${path.module}/id_rsa")
#            host        = self.ipv4_address
#        }
#    }
#
#    
#    # Copia el archivo attachHost-satellite-location.sh
#    provisioner "file" {
#        source      = "${path.module}/attachHost-satellite-location.sh"
#        destination = "/home/attachHost-satellite-location.sh"
#
#        connection {
#            type        = "ssh"
#            user        = "root"
#            private_key = file("${path.module}/id_rsa")
#            host        = self.ipv4_address
#        }
#    }
#
#    provisioner "remote-exec" {
#        inline = [
#            "chmod +x /home/setup_satellite.sh",
#            "/home/setup_satellite.sh",
#            "chmod +x /home/attachHost-satellite-location.sh",
#            "nohup bash /home/attachHost-satellite-location.sh &"
#        ]
#
#        connection {
#            type        = "ssh"
#            user        = "root"
#            private_key = file("${path.module}/id_rsa")
#            host        = self.ipv4_address
#        }
#    }
#}
