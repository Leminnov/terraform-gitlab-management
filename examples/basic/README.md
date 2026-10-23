# Basic Example

Minimal usage of the module: one group-level CI/CD variable. Start here and add the other inputs as needed (see [`../complete`](../complete)).

## What this example does

- Creates one `gitlab_group_variable` (`PIPELINE_LOG_LEVEL = info`) in the group you pass as `group`.

## Prerequisites

- OpenTofu >= 1.11.
- A group on gitlab.com or a self-managed GitLab where you have the Maintainer role or higher.
- A token with the `api` scope for that group (a group access token is enough), kept in your secret store.

## Usage

The provider reads its token from the environment. Pass it for the command only, from your secret store, never through `export` or a file; set `GITLAB_BASE_URL` for a self-managed GitLab:

```sh
tofu init
GITLAB_TOKEN="$(bao kv get -field=token kv/gitlab/terraform)" tofu apply -var 'group=my-org/platform'
```

## Cleanup

```sh
GITLAB_TOKEN="$(bao kv get -field=token kv/gitlab/terraform)" tofu destroy -var 'group=my-org/platform'
```
