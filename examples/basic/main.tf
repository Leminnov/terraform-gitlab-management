variable "group" {
  description = "Full path or numeric ID of a group you can manage (Maintainer role or higher), for example my-org/platform."
  type        = string
}

module "gitlab_management" {
  source = "../.."

  group_variables = {
    pipeline_log_level = {
      key    = "PIPELINE_LOG_LEVEL"
      groups = [var.group]
      value  = "info"
    }
  }
}
