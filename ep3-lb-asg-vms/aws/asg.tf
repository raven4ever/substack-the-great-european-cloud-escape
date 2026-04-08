resource "aws_security_group" "app" {
  name   = format("%s-sg", local.app_name)
  vpc_id = aws_vpc.app.id

  ingress {
    description     = "HTTP from LB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = format("%s-sg", local.app_name)
    Project = "ep3-lb-asg-vms"
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = format("%s-", local.app_name)
  image_id      = data.aws_ami.ubuntu.id
  instance_type = local.instance_type
  user_data     = data.cloudinit_config.app.rendered

  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = local.app_name
      Project = "ep3-lb-asg-vms"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                  = local.app_name
  min_size              = 1
  max_size              = 3
  desired_capacity      = 1
  wait_for_elb_capacity = 1
  vpc_zone_identifier   = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  target_group_arns     = [aws_lb_target_group.app.arn]
  health_check_type     = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Project"
    value               = "ep3-lb-asg-vms"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = format("%s-scale-out", local.app_name)
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = format("%s-cpu-high", local.app_name)
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 50
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = format("%s-scale-in", local.app_name)
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = format("%s-cpu-low", local.app_name)
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}
