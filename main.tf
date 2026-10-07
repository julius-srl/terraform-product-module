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

# one GitHub Environment per name, e.g. ["dev", "prod"]
# ponytail: on a Free org only public repos can have environments
variable "environments" {
  type    = list(string)
  default = []
}

locals {
  # published path in the new repo => file in ./template
  template = {
    "README.md"                 = "README.md"
    ".github/workflows/ci.yml" = "ci.yml"
  }
}

resource "github_repository" "this" {
  name        = var.name
  description = var.description
  visibility  = var.visibility
  archived    = var.archived
  auto_init   = true
}

resource "github_repository_environment" "this" {
  for_each = toset(var.environments)

  repository  = github_repository.this.name
  environment = each.key
}

# ponytail: one-off push of the template, ignore_changes keeps devs' edits. Real factory may use a template repo + pipeline step.
resource "github_repository_file" "template" {
  for_each = local.template

  repository          = github_repository.this.name
  branch              = "main"
  file                = each.key
  content             = file("${path.module}/template/${each.value}")
  commit_message      = "chore: product template"
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [content]
  }
}

output "repo_url" { value = github_repository.this.html_url }
output "repo_id" { value = github_repository.this.repo_id }
output "environments" { value = [for e in github_repository_environment.this : e.environment] }
