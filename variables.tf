## // NSX SYSTEM > APPLIANCE VARIABLES //

variable "nsx_manager" {
    default = "nsx01.pod3.demo"
}
 
variable "username" {
  default = "admin"
}
 
variable "password" {
    default = "VMware1!VMware1!"
}

## // NSX SYSTEM > FABRIC VARIABLES //
 
variable "overlay_tz" {
   default = "nsx-overlay-transportzone"
}

variable "vlan_tz" {
   default = "nsx-vlan-transportzone"
}

variable "edge_node_a" {
   default = "edge03a"
}

variable "edge_node_b" {
   default = "edge03b"
}

variable "edge_cluster" {
   default = "Pod3-EC-03"
}
