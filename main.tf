provider "aws" {
  profile = var.aws_account
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
  region = "us-east-1"

  tags = {
    Name = var.svc_name
  }
}

################################################################################
# VPC
################################################################################

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  tags = {
    Type = "Private"
  }

}

data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  tags = {
    Type = "Public"
  }

}

################################################################################
# Secrets
################################################################################

data "aws_secretsmanager_secret" "secrets" {
  arn = var.secret_arn
}

data "aws_secretsmanager_secret_version" "current" {
  secret_id = data.aws_secretsmanager_secret.secrets.id
}

################################################################################
# S3
################################################################################

data "aws_s3_bucket" "current" {
  count = var.create_logs_bucket ? 0 : 1
  bucket = var.s3_logs_bucket
}

################################################################################
# Service
################################################################################

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"

  name        = var.svc_name
  cluster_arn = var.cluster_arn

  cpu    = var.task_cpu
  memory = var.task_memory

  # Enables ECS Exec
  enable_execute_command = true

  create_tasks_iam_role = (var.tasks_iam_role_arn == null 
                        && var.tasks_iam_role_aws_policies == null 
                        && var.tasks_iam_role_customer_policies == null) ? true : false
  tasks_iam_role_arn = var.tasks_iam_role_arn != null ? var.tasks_iam_role_arn : aws_iam_role.iam_role[0].arn

  # Container definition(s)
  container_definitions = {

    (var.container_name) = {
      cpu       = var.container_cpu
      memory    = var.container_memory_hard // Hard limit
      memory_reservation = var.container_memory_soft // Soft limit
      essential = true
      image     = var.container_image
      port_mappings = [
        {
          name          = var.container_name
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["environment_variables"]

     
     # Example image used requires access to write to root filesystem
      readonly_root_filesystem = false

      enable_cloudwatch_logging = true
    }
  }

  load_balancer = {
    service = {
      target_group_arn = module.alb.target_groups["${var.svc_name}-tg"].arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  desired_count = var.desired_count

  autoscaling_min_capacity = var.desired_count
  autoscaling_max_capacity = 10

  subnet_ids = data.aws_subnets.private_subnets.ids

  security_group_ids = [aws_security_group.common_sg.id]

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.0"

  name = "${var.svc_name}-alb"

  load_balancer_type = "application"
  internal = var.alb_internal

  vpc_id  = data.aws_vpc.vpc.id
  subnets = var.alb_internal ? data.aws_subnets.private_subnets.ids : data.aws_subnets.public_subnets.ids

  # For example only
  enable_deletion_protection = false

  xff_header_processing_mode = var.alb_xff_header_processing_mode

  security_groups = [aws_security_group.common_sg.id]

  access_logs = {
    bucket  = var.create_logs_bucket == true ? module.s3_bucket[0].s3_bucket_id : data.aws_s3_bucket.current[0].bucket
    prefix  = var.svc_name
    enabled = true
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "${var.svc_name}-tg"
      }
    }
  }

  target_groups = {
    "${var.svc_name}-tg" = {
      backend_protocol                  = "HTTP"
      backend_port                      = var.container_port
      target_type                       = "ip"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = var.health_check_matcher
        path                = var.health_check_path
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      # There's nothing to attach here in this definition. Instead,
      # ECS will attach the IPs of the tasks to this target group
      create_attachment = false
    }
  }

  tags = local.tags
}

resource "aws_security_group" "common_sg" {
  name        = "${var.svc_name}-sg"
  description = "Security group for ALB and ECS service for ${var.svc_name}. Managed by Terraform"
  vpc_id      = data.aws_vpc.vpc.id

  lifecycle {
    ignore_changes = [
      tags,
      description
    ]
  }
  
  dynamic ingress {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      description = ingress.value.description

      # Conditional attributes
      self             = lookup(ingress.value, "self", false)
      cidr_blocks      = lookup(ingress.value, "cidr_blocks", [])
      ipv6_cidr_blocks = lookup(ingress.value, "ipv6_cidr_blocks", [])
      security_groups  = lookup(ingress.value, "security_groups", [])
    }
    
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.svc_name}-sg"
  }
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.2"


  count = var.create_logs_bucket ? 1 : 0

  bucket = var.s3_logs_bucket
  acl    = "log-delivery-write"

  # Allow deletion of non-empty bucket
  force_destroy = true

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  attach_elb_log_delivery_policy = true  # Required for ALB logs
  attach_lb_log_delivery_policy  = true  # Required for ALB/NLB logs

  tags = {
    Name        = var.s3_logs_bucket
  }
  
}

resource "aws_iam_role" "iam_role" {

  count = var.tasks_iam_role_arn == null ? 1 : 0

  name = "${var.svc_name}-tf-iam-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Service = "${var.svc_name}"
  }
}

resource "aws_iam_policy" "customer_managed_policies" {
  for_each = var.tasks_iam_role_customer_policies != null ? var.tasks_iam_role_customer_policies : {}

  name        = each.value.name
  description = each.value.description
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for statement in each.value.statements : {
        Sid       = statement.sid
        Effect    = statement.effect
        Action    = statement.actions
        Resource  = statement.resources
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_managed_policy_attachments" {
  for_each = var.tasks_iam_role_aws_policies != null ? toset(var.tasks_iam_role_aws_policies) : toset([])

  role       = aws_iam_role.iam_role[0].name
  policy_arn = each.value
}


resource "aws_iam_role_policy_attachment" "customer_managed_policy_attachments" {
  for_each = aws_iam_policy.customer_managed_policies

  role       = aws_iam_role.iam_role[0].name
  policy_arn = each.value.arn
}

resource "aws_route53_record" "service_record" {

  count = var.create_dns ? 1 : 0

  zone_id = "${var.dns_zone_id}"
  name    = "${var.dns_name}"
  type    = "CNAME"
  ttl     = 60
  records = [module.alb.dns_name]

  weighted_routing_policy {
    weight = 0
  }

  set_identifier = "ecs"

  lifecycle {
    ignore_changes = [
      weighted_routing_policy
    ]
  }
}
