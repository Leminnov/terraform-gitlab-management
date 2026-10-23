# Resources live in one file per theme:
#   groups.tf  gitlab_group.level_1 ... level_7 (the tree under parent_group_id)
#   projects.tf gitlab_project, gitlab_branch, gitlab_branch_protection,
#              gitlab_tag_protection
#   access.tf  gitlab_group_deploy_token, gitlab_group_access_token,
#              gitlab_project_access_token (and the moved block from
#              gitlab_deploy_token)
#   ci.tf      gitlab_group_variable, gitlab_project_variable,
#              gitlab_pipeline_schedule, gitlab_pipeline_schedule_variable,
#              gitlab_user_runner
#   checks.tf  plan-time guardrails (check blocks)
