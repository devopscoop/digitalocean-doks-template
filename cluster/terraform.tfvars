# Spaces bucket holding OpenTofu state (created by the bootstrap step).
bucket = "project1-dev-tofu-state"

# These should be the same as the ones in bootstrap/terraform.tfvars.
cluster_name = "project1-dev"
org_name     = "devopscoop"
region       = "nyc3"

# DOKS version slug. Leave "" to track the latest release, or run
# ./update_doks_version.sh to pin the current latest into this file.
kubernetes_version = ""

# Worker node pool. Run `doctl kubernetes options sizes` for size slugs.
node_size  = "s-2vcpu-4gb"
node_count = "3"

# High-availability control plane (recommended for production; extra monthly cost).
ha_control_plane = true

enable_dns                = true
create_dns_zone           = true
zone_name                 = "project1-dev.devops.coop"
enable_container_registry = true

loki_noncurrent_version_expiration_days = 30

# Worker-node monitoring alerts (SOC 2 CC7.2 / availability). Set alert_email to
# a real inbox; thresholds are sustained-over-5m percentages. Slack is optional.
enable_monitoring_alerts = true
alert_email              = ["alerts@devops.coop"]
alert_cpu_threshold      = 80
alert_memory_threshold   = 80
alert_disk_threshold     = 85
# alert_slack_webhook_url = "https://hooks.slack.com/services/T000/B000/XXXX"
# alert_slack_channel     = "alerts"

# Private IPv4 range for the cluster VPC.
vpc_cidr = "10.0.0.0/16"

# DigitalOcean tags are flat strings. We tag resources with the source repo so
# we know what created them.
tags = ["github.com/devopscoop/project1-dev"]
