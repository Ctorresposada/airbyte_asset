output "terraform_state_management" {
  description = "Backend config block to add to the terraform configuration"
  value       = module.terraform_state_management.backend_config_terraform_block
}
