output "blue_tier0_path" {
  value       = nsxt_policy_tier0_gateway.tf-c_blue_vrf_gw
  description = "Blue Tier0 Gateway Path"
}

output "blue_tier1_path" {
  value       = nsxt_policy_tier1_gateway.tf-b_tier1_gw_blue
  description = "Blue Tier1 Gateway Path"
}