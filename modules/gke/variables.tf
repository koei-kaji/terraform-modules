variable "project" {
  type = object({
    project_id = string
    region     = string
    zone       = string
  })
}

variable "node_roles" {
  type = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    # "roles/datastore.owner",
    "roles/storage.objectViewer",
    # "roles/cloudtrace.agent", # for cloud endpoints
  ]
}

# REF: https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips#defaults_limits
variable "network" {
  type = object({
    primary_ip_range = string
    pod_range        = string
    service_range    = string
  })
  default = {
    primary_ip_range = "10.4.16.0/20" # maximum number of nodes: 4,092 -> 1,024
    pod_range        = "10.0.0.0/14"  # maximum number of nodes: 1,024 / pods: 112,640
    service_range    = "10.4.0.0/20"  # maximum number of services: 4096
  }
}

variable "cluster" {
  type = object({
    name         = string
    node_count   = number
    preemptible  = bool
    machine_type = string
  })
}
