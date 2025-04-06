variable "aws_account" {
    description = "Default AWS Account to use. This is configured in ~/.aws/credentials"
    default = "<account_name>"
}

variable "cluster_arn" {
    description = "ECS cluster ARN"
    type = string
}

variable "svc_name" {
    description = "Name of the ECS service"
    type = string
}

variable "desired_count" {
    description = "Service desired deployment count"
    type = number
    default = 1
}

variable "task_cpu" {
    description = "vCPUs the task will reserve. See https://bitly.cx/nh2b for more details"
    type = number
    default = 1024
}

variable "task_memory" {
    description = "Amount of memory the task will reserve. See https://bitly.cx/nh2b for more details"
    type = number
    default = 4096
}

variable "vpc_id" {
    description = "VPC ID to use"
    type = string
}

variable "container_name" {
    description = "Container name as it appears in the task definition"
    type = string
    default = "service_cnt"
}

variable "container_image" {
    description = "Container image for the task definition"
    type = string
}

variable "container_port" {
    description = "Container port as it appears in the task definition"
    type = number
    default = 3000
}

variable "container_cpu" {
    description = "vCPUs the container will use. See https://bitly.cx/nh2b for more details"
    type = number
    default = 1024
}

variable "container_memory_soft" {
    description = "Soft limit on memory usage for the container. Must be lower or equal to container_memory_hard. See https://bitly.cx/nh2b for more details"
    type = number
    default = 100
}

variable "container_memory_hard" {
    description = "Hard limit on memory usage for the container. Must be lower or equal to task_memory. See https://bitly.cx/nh2b for more details."
    type = number
    default = 2048
}

variable "ingress_rules" {
    description = "Ingress rules for the security group"
    type = list(object({
        from_port = number,
        to_port = number,
        protocol = number,
        description = string
        self = optional(bool)
        security_groups = optional(list(string))
        cidr_blocks =  optional(list(string))
        ipv6_cidr_blocks = optional(list(string))
    }))
    default = [
        {
            from_port   = 80
            to_port     = 80
            protocol    = 6
            description = "HTTP self"
            self        = true
        },
        {
            from_port   = 443
            to_port     = 443
            protocol    = 6
            description = "HTTPS self"
            self        = true
        },
        {
            from_port   = 3000
            to_port     = 3000
            protocol    = 6
            description = "3000 self"
            self        = true
        },
        {
            from_port   = 80
            to_port     = 80
            protocol    = 6
            description = "HTTP to rewriter"
            security_groups = ["sg-0900d22f1a6dc450e"]
        },
        {
            from_port   = 443
            to_port     = 443
            protocol    = 6
            description = "HTTPS to rewriter"
            security_groups = ["sg-0900d22f1a6dc450e"]
        },
        {
            from_port   = 3000
            to_port     = 3000
            protocol    = 6
            description = "3000 to rewriter"
            security_groups = ["sg-0900d22f1a6dc450e"]
        }
    ]
}

variable "secret_arn" {
    description = "KMS secret ARN to get the environment variables from"
    type = string
}

variable "health_check_path" {
    description = "Healthcheck path"
    type = string
    default = "/healthcheck"
}

variable "health_check_matcher" {
    description = "Status codes to match the healthcheck path"
    type = string
    default = "200,301"
}

variable "create_logs_bucket" {
    description = "Bool flag to create a new bucket for the logs or use an existing one."
    type = bool
    default = false
}

variable "s3_logs_bucket" {
    type = string
    description = "S3 Bucket to store logs from the service and ALB. If 'create_logs_bucket' is true, Terraform will create a bucket with this name."
}

variable "tasks_iam_role_arn" {
  description = "The ARN of an IAM role for the service tasks"
  type = string
  default = null
}

variable "tasks_iam_role_aws_policies" {
    description = "The IAM role policies for a newly created role for the service task. List of existing policies ONLY"
    type = list(string)
    default = null
}

variable "tasks_iam_role_customer_policies" {
  description = "Map of policy names to their policy statements"
  type = map(object({
    name        = string
    description = string
    statements  = list(object({
      sid      = string
      effect   = string
      actions  = list(string)
      resources = list(string)
    }))
  }))
  default = null
}

variable "create_dns" {
    description = "Should TF create a DNS record in the somoto.systems private zone"
    default = true
}

variable "dns_zone_id" {
    description = "The DNS zone ID for the domain name. Must be one for the TLD of the record!"
    default = null
}

variable "dns_name" {
    description = "The DNS record name in the zone"
    default = null
}

variable "alb_internal" {
    description = "Should the ALB be internal?"
    default = true
}

variable "alb_xff_header_processing_mode" {
    description = "Determines how the load balancer modifies the X-Forwarded-For header in the HTTP request before sending the request to the target. The possible values are `append`, `preserve`, and `remove`. Only valid for Load Balancers of type `application`. The default is `append`"
    default = "append"
}

variable "create_alerts" {
    description = "Bool flag to create alerts for the ECS services."
    type = bool
    default = false
}

variable "create_alerts_showstop" {
    description = "Bool flag to create showstop alerts for the ECS services."
    type = bool
    default = false
}

variable "alert_aggregation_period" {
    description = "The metric data aggregation window's duration (in seconds)."
    type = number
    default = 60
}

variable "alert_evaluation_period" {
    description = "The number of consecutive periods that must meet the alarm condition before the alarm is triggered."
    type = number
    default = 3
}