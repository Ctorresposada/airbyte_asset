terraform {
  required_version = ">= 1.11.0"

  required_providers {
    airbyte = {
      source  = "airbytehq/airbyte"
      version = "~> 1.0"
    }
  }
}
