terraform {
  required_version = ">= 1.11.0" # OpenTofu 1.11+

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 19.5"
    }
  }
}
