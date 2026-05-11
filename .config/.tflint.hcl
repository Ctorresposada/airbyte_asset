config {
  format = "compact"
  plugin_dir = "~/.tflint.d/plugins"

  # Removed the unsupported call_module_type parameter
  force = false
  disabled_by_default = false
}

plugin "aws" {
  enabled = true
  version = "0.36.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Based on Notion Terraform Conventions and recommended tflint terraform rules https://github.com/terraform-linters/tflint-ruleset-terraform/blob/main/docs/rules/README.md

plugin "terraform" {
    enabled = true
    version = "0.10.0"
    source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

# Disallow // comments in favor of #
rule "terraform_comment_syntax" {
enabled = true
}

# Disallow legacy dot index syntax
rule "terraform_deprecated_index" {
enabled = true
}

# Disallow deprecated (0.11-style) interpolation
rule "terraform_deprecated_interpolation" {
enabled = true
}

# Disallow deprecated lookup() function with only 2 arguments
rule "terraform_deprecated_lookup" {
  enabled = true
}

# Disallow output declarations without description
rule "terraform_documented_outputs" {
enabled = true
}

# Disallow variable declarations without description
rule "terraform_documented_variables" {
enabled = true
}

# Disallow comparisons with [] when checking if a collection is empty
rule "terraform_empty_list_equality" {
enabled = true
}

# Disallow duplicate keys in a map object
rule "terraform_map_duplicate_keys" {
enabled = true
}

# Disallow specifying a git or mercurial repository as a module source without pinning to a version
rule "terraform_module_pinned_source" {
enabled = true
}

# Checks that Terraform modules sourced from a registry specify a version
rule "terraform_module_version" {
enabled = true
}

# Enforces naming conventions for resources, data sources, etc
rule "terraform_naming_convention" {
enabled = true

#Require specific naming structure
variable {
format = "snake_case"
}

locals {
format = "snake_case"
}

output {
format = "snake_case"
}

#Allow any format
resource {
format = "snake_case"
}

module {
format = "snake_case"
}

data {
format = "snake_case"
}

}

# Require that all providers have version constraints through required_providers.
rule "terraform_required_providers" {
enabled = true
}

# Disallow terraform declarations without require_version.
rule "terraform_required_version" {
enabled = true
}

# Ensure that a module complies with the Terraform Standard Module Structure
rule "terraform_standard_module_structure" {
enabled = true
}

# Disallow variable declarations without type.
rule "terraform_typed_variables" {
enabled = true
}

# Disallow variables, data sources, and locals that are declared but never used.
rule "terraform_unused_declarations" {
enabled = true
}

# terraform.workspace should not be used with a "remote" backend with remote execution.
rule "terraform_workspace_remote" {
enabled = true
}
