terraform {
  required_providers {
    github = { source = "integrations/github", version = "~> 6.0" }
  }
}

variable "name" { type = string }
variable "description" { type = string }

variable "visibility" {
  type    = string
  default = "private"
}

# set to true and apply to make the repo read-only, instead of destroying it
variable "archived" {
  type    = bool
  default = false
}

# the GitHub Environment this state owns, e.g. "dev" or "prod"
# ponytail: on a Free org only public repos can have environments
variable "environment" { type = string }

# true in the first environment (dev): it creates the repo and the template.
# false elsewhere: the repo is read with a data source and must already exist.
variable "create_repo" {
  type    = bool
  default = true
}

locals {
  # published path in the new repo => file in ./template
  template = {
    "README.md"                 = "README.md"
    ".github/workflows/ci.yml" = "ci.yml"
  }
}

resource "github_repository" "this" {
  count = var.create_repo ? 1 : 0

  name        = var.name
  description = var.description
  visibility  = var.visibility
  archived    = var.archived
  auto_init   = true

  delete_branch_on_merge = true
  topics                 = ["data-product"]
}

data "github_repository" "this" {
  count = var.create_repo ? 0 : 1
  name  = var.name
}

locals {
  repo = var.create_repo ? github_repository.this[0] : data.github_repository.this[0]
}

resource "github_repository_environment" "this" {
  repository  = local.repo.name
  environment = var.environment
}

# ponytail: one-off push of the template, ignore_changes keeps devs' edits. Real factory may use a template repo + pipeline step.
resource "github_repository_file" "template" {
  for_each = var.create_repo ? local.template : {}

  repository          = local.repo.name
  branch              = "main"
  file                = each.key
  content             = file("${path.module}/template/${each.value}")
  commit_message      = "chore: product template"
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [content]
  }
}

output "repo_url" { value = local.repo.html_url }
output "repo_id" { value = local.repo.repo_id }
output "environment" { value = github_repository_environment.this.environment }
