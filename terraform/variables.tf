variable "namespace" {
  type        = string
  description = "Kubernetes namespace the app is deployed into" # new
  default     = "production"                                    # new
}

variable "environment" {
  type        = string
  description = "Value of the ENVIRONMENT variable inside the app" # new
  default     = "prod"                                             # new
}

variable "image_tag" {
  type        = string
  description = "Docker image tag to deploy" # new
  default     = "1.0.0"                      # new
}
