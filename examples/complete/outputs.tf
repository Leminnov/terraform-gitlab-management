output "resource_counts" {
  description = "Count of each resource type created by the module"
  value       = module.gitlab_management.resource_counts
}

output "all_tokens" {
  description = "All tokens (deploy, group access, project access) — sensitive"
  value       = module.gitlab_management.all_tokens
  sensitive   = true
}
