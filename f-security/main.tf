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

		data "nsxt_policy_service" "bgp" {
			display_name = "BGP"
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
  display_name = "VRF-T0-Shared-GWFW"
  category     = "LocalGatewayRules"
  locked       = false
  stateful     = true
  tcp_strict   = false

  tag {
    scope = "zone"
    tag   = "shared"
  }

    rule {
    display_name       = "Allow BGP"
    services           = [data.nsxt_policy_service.bgp.path]
    disabled           = false
    action             = "ALLOW"
    logged             = false
    scope              = [var.shared_t0]
  }

  rule {
    display_name       = "SHARED to BLUE"
    source_groups      = [nsxt_policy_group.nsx_group_shared.path]
    destination_groups = [nsxt_policy_group.nsx_group_blue.path]
    disabled           = false
    action             = "ALLOW"
    logged             = false
    scope              = [var.shared_t0]
  }

  rule {
    display_name       = "BLUE to SHARED"
    source_groups      = [nsxt_policy_group.nsx_group_blue.path]
    destination_groups = [nsxt_policy_group.nsx_group_shared.path]
    disabled           = false
    action             = "ALLOW"
    logged             = false
    scope              = [var.shared_t0]
  }

  rule {
    display_name       = "SHARED to GREEN"
    source_groups      = [nsxt_policy_group.nsx_group_shared.path]
    destination_groups = [nsxt_policy_group.nsx_group_green.path]
    disabled           = false
    action             = "ALLOW"
    logged             = false
    scope              = [var.shared_t0]
  }

  rule {
    display_name       = "GREEN to SHARED"
    source_groups      = [nsxt_policy_group.nsx_group_green.path]
    destination_groups = [nsxt_policy_group.nsx_group_shared.path]
    disabled           = false
    action             = "ALLOW"
    logged             = false
    scope              = [var.shared_t0]
  }

  rule {
    display_name = "DENY ALL"
    disabled     = false
    action       = "REJECT"
    logged       = true
    scope        = [var.shared_t0]
  }

}

## // TIER-1 GWFW RULES //

resource "nsxt_policy_gateway_policy" "nsx_t1_gwfw_shared_sec_policy" {
  display_name = "VRF-T1-Shared-GWFW"
  category     = "LocalGatewayRules"
  locked       = false
  stateful     = true
  tcp_strict   = false

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
    logged             = false
    scope              = [var.shared_t1]
  }

  rule {
    display_name       = "BLUE to SHARED"
    source_groups      = [nsxt_policy_group.nsx_group_blue.path]
    destination_groups = [nsxt_policy_group.nsx_group_shared.path]
    disabled           = false
    action             = "ALLOW"
    logged             = false
    scope              = [var.shared_t1]
  }

  rule {
    display_name       = "SHARED to GREEN"
    source_groups      = [nsxt_policy_group.nsx_group_shared.path]
    destination_groups = [nsxt_policy_group.nsx_group_green.path]
    disabled           = false
    action             = "ALLOW"
    logged             = false
    scope              = [var.shared_t1]
  }

  rule {
    display_name       = "GREEN to SHARED"
    source_groups      = [nsxt_policy_group.nsx_group_green.path]
    destination_groups = [nsxt_policy_group.nsx_group_shared.path]
    disabled           = false
    action             = "ALLOW"
    logged             = false
    scope              = [var.shared_t1]
  }

  rule {
    display_name = "DENY ALL"
    disabled     = false
    action       = "REJECT"
    logged       = true
    scope        = [var.shared_t1]
  }

}

## // VRF BLUE //

## // TIER-0 GWFW RULES //

resource "nsxt_policy_gateway_policy" "nsx_gwfw_t0_blue_sec_policy" {
  display_name = "VRF-T0-Blue-GWFW"
  category     = "LocalGatewayRules"
  locked       = false
  stateful     = true
  tcp_strict   = false

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
    logged             = false
    scope              = [var.blue_t0]
  }

  rule {
    display_name       = "BLUE to SHARED"
    source_groups      = [nsxt_policy_group.nsx_group_blue.path]
    destination_groups = [nsxt_policy_group.nsx_group_shared.path]
    disabled           = false
    action             = "ALLOW"
    logged             = false
    scope              = [var.blue_t0]
  }

  rule {
    display_name = "DENY ALL"
    disabled     = false
    action       = "REJECT"
    logged       = true
    scope        = [var.blue_t0]
  }

}

## // TIER-1 GWFW RULES //

resource "nsxt_policy_gateway_policy" "nsx_t1_gwfw_blue_sec_policy" {
  display_name = "VRF-T1-Blue-GWFW"
  category     = "LocalGatewayRules"
  locked       = false
  stateful     = true
  tcp_strict   = false

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
    logged             = false
    scope              = [var.blue_t1]
  }

  rule {
    display_name       = "BLUE to SHARED"
    source_groups      = [nsxt_policy_group.nsx_group_blue.path]
    destination_groups = [nsxt_policy_group.nsx_group_shared.path]
    disabled           = false
    action             = "ALLOW"
    logged             = false
    scope              = [var.blue_t1]
  }

  rule {
    display_name = "DENY ALL"
    disabled     = false
    action       = "REJECT"
    logged       = true
    scope        = [var.blue_t1]
  }

}

## // VRF GREEN //

## // TIER-0 GWFW RULES //

resource "nsxt_policy_gateway_policy" "nsx_gwfw_t0_green_sec_policy" {
  display_name = "VRF-T0-Green-GWFW"
  category     = "LocalGatewayRules"
  locked       = false
  stateful     = true
  tcp_strict   = false

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
    logged             = false
    scope              = [var.green_t0]
  }

  rule {
    display_name       = "GREEN to SHARED"
    source_groups      = [nsxt_policy_group.nsx_group_green.path]
    destination_groups = [nsxt_policy_group.nsx_group_shared.path]
    disabled           = false
    action             = "ALLOW"
    logged             = false
    scope              = [var.green_t0]
  }

  rule {
    display_name = "DENY ALL"
    disabled     = false
    action       = "REJECT"
    logged       = true
    scope        = [var.green_t0]
  }

}

## // TIER-1 GWFW RULES //

resource "nsxt_policy_gateway_policy" "nsx_t1_gwfw_green_sec_policy" {
  display_name = "VRF-T1-Green-GWFW"
  category     = "LocalGatewayRules"
  locked       = false
  stateful     = true
  tcp_strict   = false

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
    logged             = false
    scope              = [var.green_t1]
  }

  rule {
    display_name       = "BLUE to SHARED"
    source_groups      = [nsxt_policy_group.nsx_group_blue.path]
    destination_groups = [nsxt_policy_group.nsx_group_shared.path]
    disabled           = false
    action             = "ALLOW"
    logged             = false
    scope              = [var.green_t1]
  }

  rule {
    display_name = "DENY ALL"
    disabled     = false
    action       = "REJECT"
    logged       = true
    scope        = [var.green_t1]
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
    display_name  = "DENY BLUE"
    source_groups = [nsxt_policy_group.nsx_group_blue.path]
    action        = "REJECT"
    logged        = true
    direction     = "IN_OUT"
    ip_version    = "IPV4_IPV6"
    log_label     = "dfw-deny-all-blue"
    scope         = [nsxt_policy_group.nsx_group_blue.path]
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
    display_name  = "DENY GREEN"
    source_groups = [nsxt_policy_group.nsx_group_green.path]
    action        = "REJECT"
    logged        = true
    direction     = "IN_OUT"
    ip_version    = "IPV4_IPV6"
    log_label     = "dfw-deny-all-green"
    scope         = [nsxt_policy_group.nsx_group_green.path]
  }
}
