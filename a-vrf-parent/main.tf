# Terraform Provider
terraform {
  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = "3.2.5"
    }
  }
}

# NSX-T Manager Credentials
provider "nsxt" {
  host                  = var.nsx_manager
  username              = var.username
  password              = var.password
  allow_unverified_ssl  = true
  max_retries           = 10
  retry_min_delay       = 500
  retry_max_delay       = 5000
  retry_on_status_codes = [429]
}

## // DATA SOURCES //

# // FABRIC // 

data "nsxt_policy_transport_zone" "overlay_tz" {
  display_name = var.overlay_tz
}

data "nsxt_policy_transport_zone" "vlan_tz" {
  display_name = var.vlan_tz
}

data "nsxt_policy_edge_cluster" "edge_cluster" {
  display_name = var.edge_cluster
}

# // RESERVED FOR SERVICES // -- Example Services

#		data "nsxt_policy_service" "http" {
#			display_name = "HTTP"
#		}

#		data "nsxt_policy_service" "https" {
#			display_name = "HTTPS"
#		}

## // EDGE TRANSPORT NODES //

data "nsxt_policy_edge_node" "edge_node_a" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster.path
  display_name      = var.edge_node_a
}

data "nsxt_policy_edge_node" "edge_node_b" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster.path
  display_name      = var.edge_node_b
}

## // CREATE TIER-0 GATEWAYS //

resource "nsxt_policy_tier0_gateway" "tf-a_vrf_tier0_gw" {
  display_name         = "VRF-T0-Parent"
  description          = "VRF Tier 0"
  failover_mode        = "PREEMPTIVE"
  default_rule_logging = false
  enable_firewall      = true
  ha_mode              = "ACTIVE_STANDBY"
  transit_subnets      = ["100.111.0.0/24"]
  edge_cluster_path    = data.nsxt_policy_edge_cluster.edge_cluster.path

  bgp_config {
    ecmp            = true
    local_as_num    = "65111"
    inter_sr_ibgp   = false
    multipath_relax = true
  }
}

## // CREATE VLAN SEGMENTS FOR EDGE UPLINKS //

resource "nsxt_policy_vlan_segment" "nsx-vlan-111-seg" {
  display_name        = "nsx-vlan-111-seg"
  description         = "VRF T0 Uplink (Physical to Virtual)"
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids            = ["111"]
}

## // CREATE TIER-0 UPLINKS //

resource "nsxt_policy_tier0_gateway_interface" "uplink_en1_a_parent" {
  display_name   = "Uplink-01a"
  description    = "Parent Tier-0 Gateway Uplink to ToR-A"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_a.path
  gateway_path   = nsxt_policy_tier0_gateway.tf-a_vrf_tier0_gw.path
  segment_path   = nsxt_policy_vlan_segment.nsx-vlan-111-seg.path
  subnets        = ["10.11.1.1/24"]
}

resource "nsxt_policy_tier0_gateway_interface" "uplink_en2_a_parent" {
  display_name   = "Uplink-01b"
  description    = "Parent Tier-0 Gateway Uplink to ToR-A"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_b.path
  gateway_path   = nsxt_policy_tier0_gateway.tf-a_vrf_tier0_gw.path
  segment_path   = nsxt_policy_vlan_segment.nsx-vlan-111-seg.path
  subnets        = ["10.11.1.2/24"]
}

## // CONFIGURE BGP NEIGHBORS // 

resource "nsxt_policy_bgp_neighbor" "parent_bgp_tor_a" {
  display_name     = "Parent Tier0 BGP ToR-A"
  bgp_path         = nsxt_policy_tier0_gateway.tf-a_vrf_tier0_gw.bgp_config.0.path
  neighbor_address = "10.11.1.253"
  remote_as_num    = "65000"
}

## // CONFIGURE REDISTRIBUTION POLICIES //

resource "nsxt_policy_gateway_redistribution_config" "parent_bgp_redist" {
  gateway_path = nsxt_policy_tier0_gateway.tf-a_vrf_tier0_gw.path
  bgp_enabled  = true
  ospf_enabled = false

  rule {
    name  = "BGP Redistribute Connected"
    types = ["TIER1_CONNECTED"]
  }
}
