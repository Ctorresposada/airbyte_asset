# Stack: airbyte-connections
# Manages Airbyte sources, destinations, and connections for self-hosted Airbyte.
#
# Resources are split by type:
#   destinations.tf  - Airbyte destination connectors
#   sources.tf       - Airbyte source connectors
#   connections.tf   - Airbyte sync connections
#
# Provider 1.x exposes a single generic airbyte_source / airbyte_destination
# resource: pass a connector definition_id and a JSON `configuration` blob
# whose shape matches the connector's spec. The whole configuration attribute
# is sensitive so secrets are never written to plan/state human-readable form.
