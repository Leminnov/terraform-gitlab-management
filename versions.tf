terraform {
  required_version = ">= 1.10.7" # OpenTofu 1.10.7+
  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 18.6"
    }
  }
}
