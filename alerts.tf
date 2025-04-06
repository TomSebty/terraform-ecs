data "aws_sns_topic" "ecs_test_alert" {
  name = "ECS_Alert"
}

resource "aws_cloudwatch_metric_alarm" "healthy_targets" {
  count = var.create_alerts ? 1 : 0

  alarm_name          = "HealthyTargetsAlarm-${var.svc_name}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "${var.alert_evaluation_period}"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "${var.alert_aggregation_period}"
  statistic           = "Average"
  threshold           = max(var.desired_count - 1, 1)

  dimensions = {
    LoadBalancer = module.alb.arn_suffix
    TargetGroup  = module.alb.target_groups["${var.svc_name}-tg"].arn_suffix
  }

  alarm_description = "Alarm when the number of healthy targets is less than 2."
  alarm_actions     = [data.aws_sns_topic.ecs_test_alert.arn]
}

resource "aws_cloudwatch_metric_alarm" "errors_5xx" {
  count = var.create_alerts ? 1 : 0

  alarm_name          = "5xxErrorsAlarm-${var.svc_name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "${var.alert_evaluation_period}"
  threshold           = "4"

  metric_query {
    id          = "e1"
    expression  = "IF(m1 > 0, (m2 / m1) * 100, 0)"
    label       = "Error Rate"
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = "${var.alert_aggregation_period}"
      stat        = "Sum"
      unit        = "Count"

      dimensions = {
        LoadBalancer = module.alb.arn_suffix
      }
    }
  }

  metric_query {
    id = "m2"

    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = "${var.alert_aggregation_period}"
      stat        = "Sum"
      unit        = "Count"

      dimensions = {
        LoadBalancer = module.alb.arn_suffix
      }
    }
  }

  alarm_description = "Alarm when the percentage of 5xx responses exceeds X%."
  alarm_actions     = [data.aws_sns_topic.ecs_test_alert.arn]
}

resource "aws_cloudwatch_metric_alarm" "errors_5xx_showstop" {
  count = var.create_alerts_showstop && var.create_alerts ? 1 : 0

  alarm_name          = "5xxErrorsAlarm-${var.svc_name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "${var.alert_evaluation_period}"
  threshold           = "10"

  metric_query {
    id          = "e1"
    expression  = "IF(m1 > 0, (m2 / m1) * 100, 0)"
    label       = "Error Rate"
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = "${var.alert_aggregation_period}"
      stat        = "Sum"
      unit        = "Count"

      dimensions = {
        LoadBalancer = module.alb.arn_suffix
      }
    }
  }

  metric_query {
    id = "m2"

    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = "${var.alert_aggregation_period}"
      stat        = "Sum"
      unit        = "Count"

      dimensions = {
        LoadBalancer = module.alb.arn_suffix
      }
    }
  }

  alarm_description = "Alarm when the percentage of 5xx responses exceeds X%."
  alarm_actions     = [data.aws_sns_topic.ecs_test_alert.arn]
}

resource "aws_cloudwatch_metric_alarm" "errors_4xx" {
  count = var.create_alerts ? 1 : 0

  alarm_name          = "4xxErrorsAlarm-${var.svc_name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "${var.alert_evaluation_period}"
  threshold           = "50"

  metric_query {
    id          = "e1"
    expression  = "IF(m1 > 0, (m2 / m1) * 100, 0)"
    label       = "Error Rate"
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = "${var.alert_aggregation_period}"
      stat        = "Sum"
      unit        = "Count"

      dimensions = {
        LoadBalancer = module.alb.arn_suffix
      }
    }
  }

  metric_query {
    id = "m2"

    metric {
      metric_name = "HTTPCode_Target_4XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = "${var.alert_aggregation_period}"
      stat        = "Sum"
      unit        = "Count"

      dimensions = {
        LoadBalancer = module.alb.arn_suffix
      }
    }
  }

  alarm_description = "Alarm when the percentage of 4xx responses exceeds X%."
  alarm_actions     = [data.aws_sns_topic.ecs_test_alert.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count = var.create_alerts ? 1 : 0

  alarm_name          = "CPUUtilizationAlarm-${var.svc_name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "${var.alert_evaluation_period}"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "${var.alert_aggregation_period}"
  statistic           = "Average"
  threshold           = "80" # Adjust based on your threshold

  dimensions = {
    ClusterName = split("/", var.cluster_arn)[1]
    ServiceName = var.svc_name
  }

  alarm_description = "Alarm when the average CPU utilization exceeds the threshold."
  alarm_actions     = [data.aws_sns_topic.ecs_test_alert.arn]
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization" {
  count = var.create_alerts ? 1 : 0

  alarm_name          = "MemoryUtilizationAlarm-${var.svc_name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "${var.alert_evaluation_period}"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "${var.alert_aggregation_period}"
  statistic           = "Average"
  threshold           = "80" # Adjust based on your threshold

  dimensions = {
    ClusterName = split("/", var.cluster_arn)[1]
    ServiceName = var.svc_name
  }

  alarm_description = "Alarm when the average memory utilization exceeds the threshold."
  alarm_actions     = [data.aws_sns_topic.ecs_test_alert.arn]
}