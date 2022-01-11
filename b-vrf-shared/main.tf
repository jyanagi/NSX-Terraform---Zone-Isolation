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

resource "nsxt_policy_tier0_gateway" "tf-b_shared_vrf_gw" {
  display_name         = "VRF-T0-Shared"
  description          = "VRF Shared Services Tenant"
  failover_mode        = "PREEMPTIVE"
  default_rule_logging = false
  enable_firewall      = true
  ha_mode              = "ACTIVE_STANDBY"
  transit_subnets      = ["100.111.0.0/24"]
  edge_cluster_path    = data.nsxt_policy_edge_cluster.edge_cluster.path

  vrf_config {
    gateway_path = var.parent_t0
  }

  bgp_config {
    ecmp            = true
    inter_sr_ibgp   = false
    multipath_relax = true
  }

  tag {
    scope = "zone"
    tag   = "shared"
  }

  tag {
    tag = "demo"
  }

}

## // CREATE VLAN SEGMENTS FOR EDGE UPLINKS //

resource "nsxt_policy_vlan_segment" "nsx-vlan-112-seg" {
  display_name        = "nsx-vlan-112-seg"
  description         = "VRF Shared VLAN Segment"
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
  vlan_ids            = ["112"]
}

## // CREATE TIER-0 UPLINKS //

resource "nsxt_policy_tier0_gateway_interface" "uplink_en1_b_shared" {
  display_name   = "Uplink-01a"
  description    = "VRF Shared Services Tier-0 Gateway Uplink to ToR-A"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_a.path
  gateway_path   = nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path
  segment_path   = nsxt_policy_vlan_segment.nsx-vlan-112-seg.path
  subnets        = ["10.11.2.1/24"]
}

resource "nsxt_policy_tier0_gateway_interface" "uplink_en2_b_shared" {
  display_name   = "Uplink-01b"
  description    = "VRF Shared Services Tier-0 Gateway Uplink to ToR-A"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.edge_node_b.path
  gateway_path   = nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path
  segment_path   = nsxt_policy_vlan_segment.nsx-vlan-112-seg.path
  subnets        = ["10.11.2.2/24"]
}

## // CONFIGURE BGP NEIGHBORS // 

resource "nsxt_policy_bgp_neighbor" "shared_bgp_tor_a" {
  display_name     = "VRF Shared Services BGP ToR-A"
  bgp_path         = nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.bgp_config.0.path
  neighbor_address = "10.11.2.253"
  remote_as_num    = "65000"
  allow_as_in      = "true"
}

## // CONFIGURE REDISTRIBUTION POLICIES //

resource "nsxt_policy_gateway_redistribution_config" "shared_bgp_redist" {
  gateway_path = nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path
  bgp_enabled  = true
  ospf_enabled = false

  rule {
    name  = "BGP Redistribute Connected"
    types = ["TIER1_CONNECTED"]
  }
}

# // CONFIGURE TIER1 GATEWAYS //

resource "nsxt_policy_tier1_gateway" "tf-a_tier1_gw_shared" {
  description               = "VRF-T1-Shared"
  display_name              = "VRF Shared Tier-1 GW"
  edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
  failover_mode             = "NON_PREEMPTIVE"
  default_rule_logging      = "false"
  enable_firewall           = "true"
  enable_standby_relocation = "false"
  tier0_path                = nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path
  route_advertisement_types = ["TIER1_CONNECTED"]

  tag {
    scope = "zone"
    tag   = "shared"
  }

  tag {
    tag = "demo"
  }
}

## // CREATE OVERLAY SEGMENTS FOR VRF TENANTS //

resource "nsxt_policy_segment" "nsx_shared_segment" {
  display_name        = "nsx-vrf-shared-seg"
  connectivity_path   = nsxt_policy_tier1_gateway.tf-a_tier1_gw_shared.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path

  subnet {
    cidr = "192.168.112.253/24"
  }

  tag {
    scope = "zone"
    tag   = "shared"
  }
}
