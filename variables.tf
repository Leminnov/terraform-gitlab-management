variable "group_variables" {
  description = "Map of Gitlab group variables objects"
  type        = any
  default     = {}
}

variable "project_variables" {
  description = "Map of Gitlab project variables objects"
  type        = any
  default     = {}
}

variable "deploy_tokens" {
  description = "Map of Gitlab Deploy-Token variables objects"
  type        = any
  default     = {}
}

variable "pipeline_schedules" {
  description = "Map of Gitlab pipeline schedules"
  type        = map(any)
  default     = {}
}

variable "gitlab_runners" {
  description = "Map of Gitlab Runners"
  type        = any
  default     = {}
}

variable "gitlab_group_access_token" {
  description = "Map of Gitlab Group access token"
  type        = any
  default     = {}
}

variable "gitlab_project_access_token" {
  description = "Map of Gitlab Project access token"
  type        = any
  default     = {}
}
