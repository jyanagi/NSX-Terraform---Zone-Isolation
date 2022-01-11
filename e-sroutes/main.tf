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

## // CONFIGURE ROUTE LEAKING (STATIC ROUTES) //

resource "nsxt_policy_static_route" "shared_2_blue_sroute" {
  display_name = "Route Leak - VRF Blue"
  gateway_path = var.shared_t0
  network      = "192.168.113.0/24"

  next_hop {
    admin_distance = "1"
    ip_address     = "100.111.0.3"
  }
}

resource "nsxt_policy_static_route" "shared_2_green_sroute" {
  display_name = "Route Leak - VRF Green"
  gateway_path = var.shared_t0
  network      = "192.168.114.0/24"

  next_hop {
    admin_distance = "1"
    ip_address     = "100.111.0.5"
  }
}

resource "nsxt_policy_static_route" "blue_2_shared_sroute" {
  display_name = "Route Leak - VRF Shared Services"
  gateway_path = var.blue_t0
  network      = "192.168.112.0/24"

  next_hop {
    admin_distance = "1"
    ip_address     = "100.111.0.1"
  }
}

resource "nsxt_policy_static_route" "green_2_shared_sroute" {
  display_name = "Route Leak - VRF Shared Services"
  gateway_path = var.green_t0
  network      = "192.168.112.0/24"

  next_hop {
    admin_distance = "1"
    ip_address     = "100.111.0.1"
  }
}