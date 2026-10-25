# Resources live in one file per theme:
#   groups.tf   gitlab_group.level_1 ... level_7 (the tree under parent_group_id)
#   projects.tf gitlab_project, gitlab_branch, gitlab_branch_protection,
#               gitlab_tag_protection
#   access.tf   gitlab_group_deploy_token, gitlab_group_access_token,
#               gitlab_project_access_token (and the moved block from
#               gitlab_deploy_token), gitlab_project_deploy_token,
#               gitlab_deploy_key, gitlab_group_membership,
#               gitlab_project_membership, gitlab_group_share_group,
#               gitlab_project_share_group
#   service_accounts.tf gitlab_group_service_account,
#               gitlab_project_service_account and their access tokens
#   ci.tf       gitlab_group_variable, gitlab_project_variable,
#               gitlab_pipeline_schedule, gitlab_pipeline_schedule_variable,
#               gitlab_user_runner, gitlab_project_environment,
#               gitlab_pipeline_trigger, gitlab_project_job_token_scopes
#   metadata.tf gitlab_group_label, gitlab_project_label, gitlab_group_badge,
#               gitlab_project_badge, gitlab_project_hook
#   premium.tf  gitlab_project_approval_rule, gitlab_project_level_mr_approvals,
#               gitlab_project_push_rules, gitlab_project_protected_environment,
#               gitlab_group_hook (Premium, none planned unless set)
#   checks.tf   plan-time guardrails (check blocks)
