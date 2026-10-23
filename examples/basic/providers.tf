terraform {
  required_version = ">= 1.11.0"

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 19.5"
    }
  }
}

# Base URL and token come from the environment (GITLAB_BASE_URL, GITLAB_TOKEN;
# see README.md), never from code.
provider "gitlab" {}
