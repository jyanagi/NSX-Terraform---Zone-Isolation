terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
      version = "3.2.5"
    }
  }
}

# NSX-T Manager Credentials
provider "nsxt" { }

module "vrf_parent" {
  source = "./a-vrf-parent"
}

module "vrf_shared" {
  source = "./b-vrf-shared"
  parent_t0 = module.vrf_parent.parent_tier0_path.path
}

module "vrf_blue" {
  source = "./c-vrf-blue"
  parent_t0 = module.vrf_parent.parent_tier0_path.path
}

module "vrf_green" {
  source = "./d-vrf-green"
  parent_t0 = module.vrf_parent.parent_tier0_path.path
}

module "sroutes" {
  source = "./e-sroutes"
  shared_t0 = module.vrf_shared.shared_tier0_path.path
  blue_t0 = module.vrf_blue.blue_tier0_path.path
  green_t0 = module.vrf_green.green_tier0_path.path
}

module "security" {
  source = "./f-security"
  shared_t0 = module.vrf_shared.shared_tier0_path.path
  blue_t0 = module.vrf_blue.blue_tier0_path.path
  green_t0 = module.vrf_green.green_tier0_path.path
  shared_t1 = module.vrf_shared.shared_tier1_path.path
  blue_t1 = module.vrf_blue.blue_tier1_path.path
  green_t1 = module.vrf_green.green_tier1_path.path
}