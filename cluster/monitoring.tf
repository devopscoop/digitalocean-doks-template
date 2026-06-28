# Availability / resource monitoring (supports SOC 2 CC7.2 "monitoring" and the
# A1 availability criteria).
#
# DigitalOcean's monitoring agent ships on DOKS worker droplets, so these alert
# policies need nothing installed in-cluster. They watch the worker nodes -
# matched by the cluster tags that main.tf applies to the node pool - and notify
# on sustained resource exhaustion, which is the kind of signal an availability/
# monitoring control expects ongoing evidence of. Notifications go to
# var.alert_email, plus an optional Slack webhook.
#
# Scope note: this covers node-level resource health only. Kubernetes API-server
# audit logs are NOT exposed by DOKS (the control plane is fully managed), so
# they cannot be configured from this repo - track that requirement in your
# control matrix instead of expecting code here.

locals {
  # GreaterThan / 5m thresholds for the worker node pool. type slugs come from
  # DigitalOcean's insights metrics.
  monitor_alerts = {
    cpu = {
      type        = "v1/insights/droplet/cpu"
      value       = var.alert_cpu_threshold
      description = "${local.name}: worker node CPU above ${var.alert_cpu_threshold}% for 5m"
    }
    memory = {
      type        = "v1/insights/droplet/memory_utilization_percent"
      value       = var.alert_memory_threshold
      description = "${local.name}: worker node memory above ${var.alert_memory_threshold}% for 5m"
    }
    disk = {
      type        = "v1/insights/droplet/disk_utilization_percent"
      value       = var.alert_disk_threshold
      description = "${local.name}: worker node disk above ${var.alert_disk_threshold}% for 5m"
    }
  }
}

resource "digitalocean_monitor_alert" "nodes" {
  for_each = var.enable_monitoring_alerts ? local.monitor_alerts : {}

  alerts {
    email = var.alert_email

    dynamic "slack" {
      for_each = var.alert_slack_webhook_url != "" ? [1] : []
      content {
        channel = var.alert_slack_channel
        url     = var.alert_slack_webhook_url
      }
    }
  }

  description = each.value.description
  type        = each.value.type
  compare     = "GreaterThan"
  value       = each.value.value
  window      = "5m"
  enabled     = true

  # Apply to the worker droplets via the same tags main.tf sets on the node pool.
  tags = var.tags
}
