output "shared_tier0_path" {
  value       = nsxt_policy_tier0_gateway.tf-b_shared_vrf_gw
  description = "Shared Tier0 Gateway Path"
}

output "shared_tier1_path" {
  value       = nsxt_policy_tier1_gateway.tf-a_tier1_gw_shared
  description = "Shared Tier1 Gateway Path"
}