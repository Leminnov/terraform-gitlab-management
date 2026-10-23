output "pipeline_schedule_ids" {
  description = "GitLab IDs of the pipeline schedules, keyed like the module input"
  value       = module.gitlab_management.pipeline_schedule_ids
}

output "deploy_tokens" {
  description = "Deploy tokens keyed \"<entry>_<group>\" (username and token to log in to the registry); read with tofu output -json"
  value       = module.gitlab_management.deploy_tokens
  sensitive   = true
}

output "project_deploy_tokens" {
  description = "Project deploy tokens keyed \"<project key>:<name>\" (username and token to clone the project); read with tofu output -json"
  value       = module.gitlab_management.project_deploy_tokens
  sensitive   = true
}

output "gitlab_runner_tokens" {
  description = "Runner authentication tokens keyed like the module input, for registering the runner manager; read with tofu output -json"
  value       = module.gitlab_management.gitlab_runner_tokens
  sensitive   = true
}
