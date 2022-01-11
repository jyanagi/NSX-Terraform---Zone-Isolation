output "green_tier0_path" {
  value       = nsxt_policy_tier0_gateway.tf-d_green_vrf_gw
  description = "Green Tier0 Gateway Path"
}

output "green_tier1_path" {
  value       = nsxt_policy_tier1_gateway.tf-c_tier1_gw_green
  description = "Green Tier1 Gateway Path"
}