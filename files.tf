# Files committed to the default branch of created projects. Managed files
# are owned by Terraform (edits in the repository are reverted); seeded files
# are committed once and then owned by the project's developers. Each block
# holds one ownership model, since ignore_changes cannot vary per instance.

resource "gitlab_repository_file" "managed" {
  for_each = { for k, f in local.repository_files : k => f if f.managed }

  project          = local.project_ids[each.value.project_key]
  branch           = var.projects[each.value.project_key].default_branch
  file_path        = each.value.file_path
  content          = each.value.content
  encoding         = each.value.encoding
  execute_filemode = each.value.executable
  # A new project holds only the README that initialize_with_readme commits,
  # which a file may replace.
  overwrite_on_create   = true
  create_commit_message = "Add ${each.value.file_path}"
  update_commit_message = "Update ${each.value.file_path}"
  delete_commit_message = "Remove ${each.value.file_path}"
}

resource "gitlab_repository_file" "seeded" {
  for_each = { for k, f in local.repository_files : k => f if !f.managed }

  project               = local.project_ids[each.value.project_key]
  branch                = var.projects[each.value.project_key].default_branch
  file_path             = each.value.file_path
  content               = each.value.content
  encoding              = each.value.encoding
  execute_filemode      = each.value.executable
  overwrite_on_create   = true
  create_commit_message = "Add ${each.value.file_path}"
  update_commit_message = "Update ${each.value.file_path}"
  delete_commit_message = "Remove ${each.value.file_path}"

  lifecycle {
    ignore_changes = [content, encoding, execute_filemode]
  }
}
