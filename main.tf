#   Copyright 2018 NephoSolutions SPRL, Sebastian Trebitz
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

data "google_client_config" "current" {
}

locals {
  bucket_name = var.name
  location    = var.region != "" ? var.region : data.google_client_config.current.region
  project_id  = var.project_id != "" ? var.project_id : data.google_client_config.current.project
}

resource "google_storage_bucket" "default" {
  name          = local.bucket_name
  location      = local.location
  project       = local.project_id
  storage_class = var.storage_class
  force_destroy = var.force_destroy

  lifecycle {
    // TODO Should be set to "${var.prevent_destroy}" once https://github.com/hashicorp/terraform/issues/3116 is fixed.
    prevent_destroy = false
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      dynamic "action" {
        for_each = lookup(lifecycle_rule.value, "action", [])
        content {
          storage_class = lookup(action.value, "storage_class", null)
          type          = action.value.type
        }
      }

      dynamic "condition" {
        for_each = lookup(lifecycle_rule.value, "condition", [])
        content {
          age                   = lookup(condition.value, "age", null)
          created_before        = lookup(condition.value, "created_before", null)
          is_live               = lookup(condition.value, "is_live", null)
          matches_storage_class = lookup(condition.value, "matches_storage_class", null)
          num_newer_versions    = lookup(condition.value, "num_newer_versions", null)
          with_state            = lookup(condition.value, "with_state", null)
        }
      }
    }
  }

  logging {
    log_bucket = google_storage_bucket.logging.name
  }

  versioning {
    enabled = var.versioning
  }

  dynamic "website" {
    for_each = [var.website_config]
    content {
      main_page_suffix = lookup(website.value, "main_page_suffix", null)
      not_found_page   = lookup(website.value, "not_found_page", null)
    }
  }
}

resource "google_storage_bucket" "logging" {
  name          = "${replace(local.bucket_name, ".", "-")}-logs"
  location      = local.location
  project       = local.project_id
  storage_class = var.storage_class

  lifecycle {
    // TODO Should be set to "${var.prevent_destroy}" once https://github.com/hashicorp/terraform/issues/3116 is fixed.
    prevent_destroy = false
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 90
    }
  }
}

