# ---------------------------------------------------------------------------
# Connections: Oracle → S3 Data Lake
# ---------------------------------------------------------------------------
resource "airbyte_connection" "oracle_to_s3" {
  count          = var.create_oracle_connection ? 1 : 0
  source_id      = airbyte_source.oracle[0].source_id
  destination_id = airbyte_destination.data_lake[0].destination_id

  name = "Oracle DB Region 20 → S3 Data Lake Oracle"

  namespace_definition                 = "destination"
  non_breaking_schema_updates_behavior = "ignore"
  prefix                               = ""
  status                               = "active"

  schedule = {
    schedule_type = "manual"
  }

  configurations = {
    streams = [
      {
        name         = "CMT_ENROLLMENT"
        namespace    = "BOLINF"
        sync_mode    = "full_refresh_overwrite"
        cursor_field = ["CREATION_DATE"]
        primary_key  = [["CMT_FORM_ID"], ["PERIOD_ID"]]
      },
      {
        name         = "CMT_FORM"
        namespace    = "BOLINF"
        sync_mode    = "full_refresh_overwrite"
        cursor_field = ["DATE_CREATED"]
        primary_key  = [["CMT_FORM_ID"], ["PERIOD_ID"]]
      },
      {
        name         = "CMT_FORM_ITEM"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["DATE_MODIFIED"]
        primary_key  = [["CMT_FORM_ITEM_ID"]]
      },
      {
        name         = "CMT_FORM_ITEM_GROUP"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["DATE_MODIFIED"]
        primary_key  = [["CMT_FORM_ITEM_GROUP_ID"]]
      },
      {
        name         = "CONTACT"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["DATE_MODIFIED"]
        primary_key  = [["CONTACT_ID"]]
      },
      {
        name         = "CONTACT_ADDRESS"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["DATE_MODIFIED"]
        primary_key  = [["CONTACT_ADDRESS_ID"]]
      },
      {
        name         = "CONTACT_ADDRESS_TYPE"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["DATE_MODIFIED"]
        primary_key  = [["CONTACT_ADDRESS_TYPE_ID"]]
      },
      {
        name         = "CONTACT_CAMPUS"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["DATE_MODIFIED"]
        primary_key  = [["CONTACT_CAMPUS_ID"]]
      },
      {
        name         = "CONTACT_COUNTRY"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["DATE_MODIFIED"]
        primary_key  = [["CONTACT_COUNTRY_ID"]]
      },
      {
        name         = "CONTACT_COUNTY"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["DATE_MODIFIED"]
        primary_key  = [["CONTACT_COUNTY_ID"]]
      },
      {
        name         = "CONTACT_DISTRICT"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["DATE_MODIFIED"]
        primary_key  = [["CONTACT_DISTRICT_ID"]]
      },
      {
        name         = "CONTACT_REGION"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["DATE_MODIFIED"]
        primary_key  = [["CONTACT_REGION_ID"]]
      },
      {
        name         = "CONTRACT_REVIEWERS"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["REVIEWED_DATE"]
        primary_key  = [["REVIEW_ID"]]
      },
      {
        name         = "CONTACT_CAMPUS_COUNTS"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["UPDATED_DATE"]
        primary_key  = [["ID"]]
      },
      {
        name         = "CMT_NETVISION_PRICE"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["UPDATE_DATE"]
        primary_key  = [["ID"]]
      },
      {
        name         = "CMT_NON_NETVISION_PRICE"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["UPDATE_DATE"]
        primary_key  = [["ID"]]
      },
      {
        name         = "CMT_PERIOD"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["UPDATE_DATE"]
        primary_key  = [["PERIOD_ID"]]
      },
      {
        name         = "CONTACT_DISTRICT_COUNTS"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["UPDATE_DATE"]
        primary_key  = [["ID"]]
      },
      {
        name         = "CONTRACT_INVOICE"
        namespace    = "BOLINF"
        sync_mode    = "incremental_deduped_history"
        cursor_field = ["UPDATE_DATE"]
        primary_key  = [["ID"]]
      },
      {
        name         = "CMT_RANGE_PRICE_FORMS"
        namespace    = "BOLINF"
        sync_mode    = "full_refresh_overwrite"
        cursor_field = []
      },
      {
        name         = "CONTRACT_DETAILS"
        namespace    = "BOLINF"
        sync_mode    = "full_refresh_overwrite"
        cursor_field = []
        primary_key  = [["CONTRACT_ID"]]
      },
    ]
  }
}
