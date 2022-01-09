# Terraform Provider
terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
      version = "3.2.5"
    }
  }
}
 
# NSX-T Manager Credentials
provider "nsxt" {
    host                     = var.nsx_manager
    username                 = var.username
    password                 = var.password
    allow_unverified_ssl     = true
    max_retries              = 10
    retry_min_delay          = 500
    retry_max_delay          = 5000
    retry_on_status_codes    = [429]
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
	   edge_cluster_path   = data.nsxt_policy_edge_cluster.edge_cluster.path
	   display_name        = var.edge_node_a
	}
	 
	data "nsxt_policy_edge_node" "edge_node_b" {
	   edge_cluster_path   = data.nsxt_policy_edge_cluster.edge_cluster.path
	   display_name        = var.edge_node_b
	}
	
## // CREATE TIER-0 GATEWAYS //

	resource "nsxt_policy_tier0_gateway" "tf-a_vrf_tier0_gw" {
		display_name              = "VRF-T0-Parent"
		description               = "VRF Tier 0"
		failover_mode             = "PREEMPTIVE"
		default_rule_logging      = false
		enable_firewall           = false
		ha_mode                   = "ACTIVE_STANDBY"
		transit_subnets           = ["100.111.0.0/24"]
		edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
	 
		bgp_config {
			ecmp            = true               
			local_as_num    = "65111"
			inter_sr_ibgp   = false
			multipath_relax = true
		}
	}

	resource "nsxt_policy_tier0_gateway" "tf-b_shared_vrf_gw" {
		display_name              = "VRF-T0-Shared"
		description               = "VRF Shared Services Tenant"
		failover_mode             = "PREEMPTIVE"
		default_rule_logging      = false
		enable_firewall           = false
		ha_mode                   = "ACTIVE_STANDBY"
		transit_subnets           = ["100.111.0.0/24"]
		edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
	 
		vrf_config {
			gateway_path    = nsxt_policy_tier0_gateway.tf-a_vrf_tier0_gw.path
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
			tag   = "demo"
		}

		depends_on = [nsxt_policy_tier0_gateway.tf-a_vrf_tier0_gw]
	}

	resource "nsxt_policy_tier0_gateway" "tf-c_blue_vrf_gw" {
		display_name              = "VRF-T0-Blue"
		description               = "VRF Blue Tenant"
		failover_mode             = "PREEMPTIVE"
		default_rule_logging      = false
		enable_firewall           = false
		ha_mode                   = "ACTIVE_STANDBY"
		transit_subnets           = ["100.111.0.0/24"]
		edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
	 
		vrf_config {
			gateway_path    = nsxt_policy_tier0_gateway.tf-a_vrf_tier0_gw.path
		}
			 
		tag {
			scope = "zone"
			tag   = "blue"
		}

		tag {
			tag   = "demo"
		}
		
		depends_on = [nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw]
	}

	resource "nsxt_policy_tier0_gateway" "tf-d_green_vrf_gw" {
		display_name              = "VRF-T0-Green"
		description               = "VRF Green Tenant"
		failover_mode             = "PREEMPTIVE"
		default_rule_logging      = false
		enable_firewall           = false
		ha_mode                   = "ACTIVE_STANDBY"
		transit_subnets           = ["100.111.0.0/24"]
		edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
	 
		vrf_config {
			gateway_path    = nsxt_policy_tier0_gateway.tf-a_vrf_tier0_gw.path
		}
	 
		tag {
			scope = "zone"
			tag   = "green"
		}
		
		tag {
			tag   = "demo"
		}

		depends_on = [nsxt_policy_tier0_gateway.tf-c_blue_vrf_gw]
	}

## // CREATE VLAN SEGMENTS FOR EDGE UPLINKS //

	resource "nsxt_policy_vlan_segment" "nsx-vlan-111-seg" {
		display_name = "nsx-vlan-111-seg"
		description = "VRF T0 Uplink (Physical to Virtual)"
		transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
		vlan_ids = ["111"]
	}
	 
	resource "nsxt_policy_vlan_segment" "nsx-vlan-112-seg" {
		display_name = "nsx-vlan-112-seg"
		description = "VRF Shared VLAN Segment"
		transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
		vlan_ids = ["112"]
	}	

	resource "nsxt_policy_vlan_segment" "nsx-vlan-113-seg" {
		display_name = "nsx-vlan-113-seg"
		description = "VRF Blue VLAN Segment"
		transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
		vlan_ids = ["113"]
	}

	resource "nsxt_policy_vlan_segment" "nsx-vlan-114-seg" {
		display_name = "nsx-vlan-114-seg"
		description = "VRF Green VLAN Segment"
		transport_zone_path = data.nsxt_policy_transport_zone.vlan_tz.path
		vlan_ids = ["114"]
	}

## // CREATE TIER-0 UPLINKS //
	
	resource "nsxt_policy_tier0_gateway_interface" "uplink_en1_a_parent" {
		display_name        = "Uplink-01a"
		description         = "Parent Tier-0 Gateway Uplink to ToR-A"
		type                = "EXTERNAL"
		edge_node_path      = data.nsxt_policy_edge_node.edge_node_a.path
		gateway_path        = nsxt_policy_tier0_gateway.tf-a_vrf_tier0_gw.path
		segment_path        = nsxt_policy_vlan_segment.nsx-vlan-111-seg.path
		subnets             = ["10.11.1.1/24"]
	}
	 
	resource "nsxt_policy_tier0_gateway_interface" "uplink_en2_a_parent" {
		display_name        = "Uplink-01b"
		description         = "Parent Tier-0 Gateway Uplink to ToR-A"
		type                = "EXTERNAL"
		edge_node_path      = data.nsxt_policy_edge_node.edge_node_b.path
		gateway_path        = nsxt_policy_tier0_gateway.tf-a_vrf_tier0_gw.path
		segment_path        = nsxt_policy_vlan_segment.nsx-vlan-111-seg.path
		subnets             = ["10.11.1.2/24"]
	}

	resource "nsxt_policy_tier0_gateway_interface" "uplink_en1_b_shared" {
		display_name        = "Uplink-01a"
		description         = "VRF Shared Services Tier-0 Gateway Uplink to ToR-A"
		type                = "EXTERNAL"
		edge_node_path      = data.nsxt_policy_edge_node.edge_node_a.path
		gateway_path        = nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path
		segment_path        = nsxt_policy_vlan_segment.nsx-vlan-112-seg.path
		subnets             = ["10.11.2.1/24"]
		depends_on = [nsxt_policy_tier0_gateway_interface.uplink_en1_a_parent]

	}
	 
	resource "nsxt_policy_tier0_gateway_interface" "uplink_en2_b_shared" {
		display_name        = "Uplink-01b"
		description         = "VRF Shared Services Tier-0 Gateway Uplink to ToR-A"
		type                = "EXTERNAL"
		edge_node_path      = data.nsxt_policy_edge_node.edge_node_b.path
		gateway_path        = nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path
		segment_path        = nsxt_policy_vlan_segment.nsx-vlan-112-seg.path
		subnets             = ["10.11.2.2/24"]
		depends_on = [nsxt_policy_tier0_gateway_interface.uplink_en2_a_parent]
	}

	resource "nsxt_policy_tier0_gateway_interface" "uplink_en1_c_blue" {
		display_name        = "Uplink-01a"
		description         = "VRF Blue Tier-0 Gateway Uplink to ToR-A"
		type                = "EXTERNAL"
		edge_node_path      = data.nsxt_policy_edge_node.edge_node_a.path
		gateway_path        = nsxt_policy_tier0_gateway.tf-c_blue_vrf_gw.path
		segment_path        = nsxt_policy_vlan_segment.nsx-vlan-113-seg.path
		subnets             = ["10.11.3.1/24"]
		depends_on = [nsxt_policy_tier0_gateway_interface.uplink_en1_a_parent]
	}
	 
	resource "nsxt_policy_tier0_gateway_interface" "uplink_en2_c_blue" {
		display_name        = "Uplink-01b"
		description         = "VRF Blue Tier-0 Gateway Uplink to ToR-A"
		type                = "EXTERNAL"
		edge_node_path      = data.nsxt_policy_edge_node.edge_node_b.path
		gateway_path        = nsxt_policy_tier0_gateway.tf-c_blue_vrf_gw.path
		segment_path        = nsxt_policy_vlan_segment.nsx-vlan-113-seg.path
		subnets             = ["10.11.3.2/24"]
		depends_on = [nsxt_policy_tier0_gateway_interface.uplink_en2_a_parent]
	}

	resource "nsxt_policy_tier0_gateway_interface" "uplink_en1_d_green" {
		display_name        = "Uplink-01a"
		description         = "VRF Green Tier-0 Gateway Uplink to ToR-A"
		type                = "EXTERNAL"
		edge_node_path      = data.nsxt_policy_edge_node.edge_node_a.path
		gateway_path        = nsxt_policy_tier0_gateway.tf-d_green_vrf_gw.path
		segment_path        = nsxt_policy_vlan_segment.nsx-vlan-114-seg.path
		subnets             = ["10.11.4.1/24"]
		depends_on = [nsxt_policy_tier0_gateway_interface.uplink_en1_a_parent]
	}
	 
	resource "nsxt_policy_tier0_gateway_interface" "uplink_en2_d_green" {
		display_name        = "Uplink-01b"
		description         = "VRF Green Tier-0 Gateway Uplink to ToR-A"
		type                = "EXTERNAL"
		edge_node_path      = data.nsxt_policy_edge_node.edge_node_b.path
		gateway_path        = nsxt_policy_tier0_gateway.tf-d_green_vrf_gw.path
		segment_path        = nsxt_policy_vlan_segment.nsx-vlan-114-seg.path
		subnets             = ["10.11.4.2/24"]
		depends_on = [nsxt_policy_tier0_gateway_interface.uplink_en2_a_parent]
	}	

## // CONFIGURE BGP NEIGHBORS // 

	resource "nsxt_policy_bgp_neighbor" "parent_bgp_tor_a" {
		display_name        = "Parent Tier0 BGP ToR-A"
		bgp_path            = nsxt_policy_tier0_gateway.tf-a_vrf_tier0_gw.bgp_config.0.path
		neighbor_address    = "10.11.1.253"
		remote_as_num       = "65000"
	}

	resource "nsxt_policy_bgp_neighbor" "shared_bgp_tor_a" {
		display_name        = "VRF Shared Services BGP ToR-A"
		bgp_path            = nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.bgp_config.0.path
		neighbor_address    = "10.11.2.253"
		remote_as_num       = "65000"
		allow_as_in	    = "true"
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

	resource "nsxt_policy_gateway_redistribution_config" "shared_bgp_redist" {
		gateway_path = nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path
		bgp_enabled  = true
		ospf_enabled = false

		rule {
			name  = "BGP Redistribute Connected"
			types = ["TIER1_CONNECTED"]
		}
	}

## // CONFIGURE ROUTE LEAKING (STATIC ROUTES) //
	
	resource "nsxt_policy_static_route" "shared_2_blue_sroute" {
		display_name = "Route Leak - VRF Blue"
		gateway_path = nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path
		network      = "192.168.113.0/24"

		next_hop {
			admin_distance = "1"
			ip_address     = "100.111.0.3"
		}
	}

	resource "nsxt_policy_static_route" "shared_2_green_sroute" {
		display_name = "Route Leak - VRF Green"
		gateway_path = nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path
		network      = "192.168.114.0/24"

		next_hop {
			admin_distance = "1"
			ip_address     = "100.111.0.5"
		}
	}

	resource "nsxt_policy_static_route" "blue_2_shared_sroute" {
		display_name = "Route Leak - VRF Shared Services"
		gateway_path = nsxt_policy_tier0_gateway.tf-c_blue_vrf_gw.path
		network      = "192.168.112.0/24"

		next_hop {
			admin_distance = "1"
			ip_address     = "100.111.0.1"
		}
	}

	resource "nsxt_policy_static_route" "green_2_shared_sroute" {
		display_name = "Route Leak - VRF Shared Services"
		gateway_path = nsxt_policy_tier0_gateway.tf-d_green_vrf_gw.path
		network      = "192.168.112.0/24"

		next_hop {
			admin_distance = "1"
			ip_address     = "100.111.0.1"
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

	resource "nsxt_policy_tier1_gateway" "tf-b_tier1_gw_blue" {
		description               = "VRF-T1-Blue"
		display_name              = "VRF Blue Tier-1 GW"
		edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
		failover_mode             = "NON_PREEMPTIVE"
		default_rule_logging      = "false"
		enable_firewall           = "true"
		enable_standby_relocation = "false"
		tier0_path                = nsxt_policy_tier0_gateway.tf-c_blue_vrf_gw.path
		route_advertisement_types = ["TIER1_CONNECTED"]
	 
		tag {
			scope = "zone"
			tag   = "blue"
		}
		
		tag {
			tag = "demo"
		}
	}

	resource "nsxt_policy_tier1_gateway" "tf-c_tier1_gw_green" {
		description               = "VRF-T1-Green"
		display_name              = "VRF Green Tier-1 GW"
		edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
		failover_mode             = "NON_PREEMPTIVE"
		default_rule_logging      = "false"
		enable_firewall           = "true"
		enable_standby_relocation = "false"
		tier0_path                = nsxt_policy_tier0_gateway.tf-d_green_vrf_gw.path
		route_advertisement_types = ["TIER1_CONNECTED"]
	 
		tag {
			scope = "zone"
			tag   = "green"
		}
		
		tag {
			tag = "demo"
		}
	}

## // CREATE OVERLAY SEGMENTS FOR VRF TENANTS //

	resource "nsxt_policy_segment" "nsx_shared_segment" {
		display_name = "nsx-vrf-shared-seg"
		connectivity_path   = nsxt_policy_tier1_gateway.tf-a_tier1_gw_shared.path
		transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
		
		subnet {
		  cidr        = "192.168.112.253/24"
		}
		
		tag {
			scope = "zone"
			tag   = "shared"
		}
	}

	resource "nsxt_policy_segment" "nsx_blue_segment" {
		display_name = "nsx-vrf-blue-seg"
		connectivity_path   = nsxt_policy_tier1_gateway.tf-b_tier1_gw_blue.path
		transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
		
		subnet {
		  cidr        = "192.168.113.253/24"
		}
		
		tag {
			scope = "zone"
			tag   = "blue"
		}
	}

	resource "nsxt_policy_segment" "nsx_green_segment" {
		display_name = "nsx-vrf-green-seg"
		connectivity_path   = nsxt_policy_tier1_gateway.tf-c_tier1_gw_green.path
		transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
		
		subnet {
		  cidr        = "192.168.114.253/24"
		}
		
		tag {
			scope = "zone"
			tag   = "green"
		}
	}

## // NSX-T SECURITY GROUPS //

resource "nsxt_policy_group" "nsx_group_blue" {
  display_name = "VRF-GRP-BLUE"
  description  = "VRF Blue Group"

  criteria {
    condition {
      key         = "Tag"
      member_type = "Segment"
      operator    = "EQUALS"
      value       = "zone|blue"
    }
  }
}

resource "nsxt_policy_group" "nsx_group_green" {
  display_name = "VRF-GRP-GREEN"
  description  = "VRF Green Group"

  criteria {
    condition {
      key         = "Tag"
      member_type = "Segment"
      operator    = "EQUALS"
      value       = "zone|green"
    }
  }
}

resource "nsxt_policy_group" "nsx_group_shared" {
  display_name = "VRF-GRP-SHARED"
  description  = "VRF Shared Group"

  criteria {
    condition {
      key         = "Tag"
      member_type = "Segment"
      operator    = "EQUALS"
      value       = "zone|shared"
    }
  }
}

## // GATEWAY FW SECURITY POLICIES //

	## // VRF SHARED //
	
		## // TIER-0 GWFW RULES //
	
			resource "nsxt_policy_gateway_policy" "nsx_gwfw_t0_shared_sec_policy" {
				display_name    = "VRF-T0-Shared-GWFW"
				category        = "LocalGatewayRules"
				locked          = false
				stateful        = true
				tcp_strict      = false

				tag {
					scope = "zone"
					tag   = "shared"
				}

				rule {
					display_name       = "SHARED to BLUE"
					source_groups      = [nsxt_policy_group.nsx_group_shared.path]
					destination_groups = [nsxt_policy_group.nsx_group_blue.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path]
				}
				
				rule {
					display_name       = "BLUE to SHARED"
					source_groups      = [nsxt_policy_group.nsx_group_blue.path]
					destination_groups = [nsxt_policy_group.nsx_group_shared.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path]
				}

				rule {
					display_name       = "SHARED to GREEN"
					source_groups      = [nsxt_policy_group.nsx_group_shared.path]
					destination_groups = [nsxt_policy_group.nsx_group_green.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path]
				}

				rule {
					display_name       = "GREEN to SHARED"
					source_groups      = [nsxt_policy_group.nsx_group_green.path]
					destination_groups = [nsxt_policy_group.nsx_group_shared.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path]
				}
				
				rule {
					display_name       = "DENY ALL"
					disabled           = false
					action             = "REJECT"
					logged             = true
					scope              = [nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw.path]
				}

			}

		## // TIER-1 GWFW RULES //
	
			resource "nsxt_policy_gateway_policy" "nsx_t1_gwfw_shared_sec_policy" {
				display_name    = "VRF-T1-Shared-GWFW"
				category        = "LocalGatewayRules"
				locked          = false
				stateful        = true
				tcp_strict      = false

				tag {
					scope = "zone"
					tag   = "shared"
				}

				rule {
					display_name       = "SHARED to BLUE"
					source_groups      = [nsxt_policy_group.nsx_group_shared.path]
					destination_groups = [nsxt_policy_group.nsx_group_blue.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier1_gateway.tf-a_tier1_gw_shared.path]
				}
				
				rule {
					display_name       = "BLUE to SHARED"
					source_groups      = [nsxt_policy_group.nsx_group_blue.path]
					destination_groups = [nsxt_policy_group.nsx_group_shared.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier1_gateway.tf-a_tier1_gw_shared.path]
				}

				rule {
					display_name       = "SHARED to GREEN"
					source_groups      = [nsxt_policy_group.nsx_group_shared.path]
					destination_groups = [nsxt_policy_group.nsx_group_green.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier1_gateway.tf-a_tier1_gw_shared.path]
				}

				rule {
					display_name       = "GREEN to SHARED"
					source_groups      = [nsxt_policy_group.nsx_group_green.path]
					destination_groups = [nsxt_policy_group.nsx_group_shared.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier1_gateway.tf-a_tier1_gw_shared.path]
				}
				
				rule {
					display_name       = "DENY ALL"
					disabled           = false
					action             = "REJECT"
					logged             = true
					scope              = [nsxt_policy_tier1_gateway.tf-a_tier1_gw_shared.path]
				}

			}

	## // VRF BLUE //
	
		## // TIER-0 GWFW RULES //
	
			resource "nsxt_policy_gateway_policy" "nsx_gwfw_t0_blue_sec_policy" {
				display_name    = "VRF-T0-Blue-GWFW"
				category        = "LocalGatewayRules"
				locked          = false
				stateful        = true
				tcp_strict      = false

				tag {
					scope = "zone"
					tag   = "blue"
				}

				rule {
					display_name       = "SHARED to BLUE"
					source_groups      = [nsxt_policy_group.nsx_group_shared.path]
					destination_groups = [nsxt_policy_group.nsx_group_blue.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier0_gateway.tf-c_blue_vrf_gw.path]
				}
				
				rule {
					display_name       = "BLUE to SHARED"
					source_groups      = [nsxt_policy_group.nsx_group_blue.path]
					destination_groups = [nsxt_policy_group.nsx_group_shared.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier0_gateway.tf-c_blue_vrf_gw.path]
				}
				
				rule {
					display_name       = "DENY ALL"
					disabled           = false
					action             = "REJECT"
					logged             = true
					scope              = [nsxt_policy_tier0_gateway.tf-c_blue_vrf_gw.path]
				}

			}

		## // TIER-1 GWFW RULES //
	
			resource "nsxt_policy_gateway_policy" "nsx_t1_gwfw_blue_sec_policy" {
				display_name    = "VRF-T1-Blue-GWFW"
				category        = "LocalGatewayRules"
				locked          = false
				stateful        = true
				tcp_strict      = false

				tag {
					scope = "zone"
					tag   = "blue"
				}

				rule {
					display_name       = "SHARED to BLUE"
					source_groups      = [nsxt_policy_group.nsx_group_shared.path]
					destination_groups = [nsxt_policy_group.nsx_group_blue.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier1_gateway.tf-b_tier1_gw_blue.path]
				}
				
				rule {
					display_name       = "BLUE to SHARED"
					source_groups      = [nsxt_policy_group.nsx_group_blue.path]
					destination_groups = [nsxt_policy_group.nsx_group_shared.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier1_gateway.tf-b_tier1_gw_blue.path]
				}
				
				rule {
					display_name       = "DENY ALL"
					disabled           = false
					action             = "REJECT"
					logged             = true
					scope              = [nsxt_policy_tier1_gateway.tf-b_tier1_gw_blue.path]
				}

			}

	## // VRF GREEN //
	
		## // TIER-0 GWFW RULES //
	
			resource "nsxt_policy_gateway_policy" "nsx_gwfw_t0_green_sec_policy" {
				display_name    = "VRF-T0-Green-GWFW"
				category        = "LocalGatewayRules"
				locked          = false
				stateful        = true
				tcp_strict      = false

				tag {
					scope = "zone"
					tag   = "green"
				}

				rule {
					display_name       = "SHARED to GREEN"
					source_groups      = [nsxt_policy_group.nsx_group_shared.path]
					destination_groups = [nsxt_policy_group.nsx_group_green.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier0_gateway.tf-d_green_vrf_gw.path]
				}
				
				rule {
					display_name       = "GREEN to SHARED"
					source_groups      = [nsxt_policy_group.nsx_group_green.path]
					destination_groups = [nsxt_policy_group.nsx_group_shared.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier0_gateway.tf-d_green_vrf_gw.path]
				}
				
				rule {
					display_name       = "DENY ALL"
					disabled           = false
					action             = "REJECT"
					logged             = true
					scope              = [nsxt_policy_tier0_gateway.tf-d_green_vrf_gw.path]
				}

			}

		## // TIER-1 GWFW RULES //
	
			resource "nsxt_policy_gateway_policy" "nsx_t1_gwfw_green_sec_policy" {
				display_name    = "VRF-T1-Green-GWFW"
				category        = "LocalGatewayRules"
				locked          = false
				stateful        = true
				tcp_strict      = false

				tag {
					scope = "zone"
					tag   = "green"
				}

				rule {
					display_name       = "SHARED to BLUE"
					source_groups      = [nsxt_policy_group.nsx_group_shared.path]
					destination_groups = [nsxt_policy_group.nsx_group_green.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier1_gateway.tf-c_tier1_gw_green.path]
				}
				
				rule {
					display_name       = "BLUE to SHARED"
					source_groups      = [nsxt_policy_group.nsx_group_blue.path]
					destination_groups = [nsxt_policy_group.nsx_group_shared.path]
					disabled           = false
					action             = "ALLOW"
					logged             = true
					scope              = [nsxt_policy_tier1_gateway.tf-c_tier1_gw_green.path]
				}
				
				rule {
					display_name       = "DENY ALL"
					disabled           = false
					action             = "REJECT"
					logged             = true
					scope              = [nsxt_policy_tier1_gateway.tf-c_tier1_gw_green.path]
				}

			}



## // DFW SECURITY POLICIES //

	## // BLUE SECURITY POLICIES //

		resource "nsxt_policy_security_policy" "nsx_sec_policy_blue" {
		  display_name = "BLUE Security Policies"
		  category     = "Environment"
		  locked       = false
		  stateful     = true
		  tcp_strict   = false

		  rule {
			display_name       = "BLUE to SHARED"
			source_groups      = [nsxt_policy_group.nsx_group_blue.path]
			destination_groups = [nsxt_policy_group.nsx_group_shared.path]
			action             = "ALLOW"
			logged             = false
			scope              = [nsxt_policy_group.nsx_group_blue.path]
			}
		
		  rule {
			display_name       = "SHARED to BLUE"
			source_groups      = [nsxt_policy_group.nsx_group_shared.path]
			destination_groups = [nsxt_policy_group.nsx_group_blue.path]
			action             = "ALLOW"
			logged             = false
			scope              = [nsxt_policy_group.nsx_group_blue.path]
			}
			
		  rule {
			display_name       = "DENY BLUE"
			source_groups      = [nsxt_policy_group.nsx_group_blue.path]
			action       	   = "REJECT"
			logged             = true
			direction          = "IN_OUT"
			ip_version         = "IPV4_IPV6"
			log_label          = "dfw-deny-all-blue"
			scope              = [nsxt_policy_group.nsx_group_blue.path]
			}
		}

	## // GREEN SECURITY POLICIES //

		resource "nsxt_policy_security_policy" "nsx_sec_policy_green" {
		  display_name = "GREEN Security Policies"
		  category     = "Environment"
		  locked       = false
		  stateful     = true
		  tcp_strict   = false

		  rule {
			display_name       = "GREEN to SHARED"
			source_groups      = [nsxt_policy_group.nsx_group_green.path]
			destination_groups = [nsxt_policy_group.nsx_group_shared.path]
			action             = "ALLOW"
			logged             = false
			scope              = [nsxt_policy_group.nsx_group_green.path]
			}
		
		  rule {
			display_name       = "SHARED to GREEN"
			source_groups      = [nsxt_policy_group.nsx_group_shared.path]
			destination_groups = [nsxt_policy_group.nsx_group_green.path]
			action             = "ALLOW"
			logged             = false
			scope              = [nsxt_policy_group.nsx_group_green.path]
			}
			
		  rule {
			display_name       = "DENY GREEN"
			source_groups      = [nsxt_policy_group.nsx_group_green.path]
			action       	   = "REJECT"
			logged             = true
			direction          = "IN_OUT"
			ip_version         = "IPV4_IPV6"
			log_label          = "dfw-deny-all-green"
			scope              = [nsxt_policy_group.nsx_group_green.path]
			}
		}

	
