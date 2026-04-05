data "aws_region" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_ecr_repository" "bot" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_cloudwatch_log_group" "bot" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 14
}

resource "aws_ecs_cluster" "main" {
  name = var.project_name
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_security_group" "bot" {
  name        = "${var.project_name}-bot"
  description = "Outbound-only for Discord API and Anthropic"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "bot" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.fargate_cpu)
  memory                   = tostring(var.fargate_memory)
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name      = "bot"
      image     = "${aws_ecr_repository.bot.repository_url}:${var.image_tag}"
      essential = true
      environment = [
        { name = "DISCORD_BOT_TOKEN", value = var.discord_bot_token },
        { name = "ANTHROPIC_API_KEY", value = var.anthropic_api_key },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.bot.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "bot" {
  name              = var.project_name
  cluster           = aws_ecs_cluster.main.id
  task_definition   = aws_ecs_task_definition.bot.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 0

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.bot.id]
    assign_public_ip = true
  }
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.bot.repository_url
  description = "docker build -t <repo>:tag . && docker tag && docker push"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "aws ecs update-service --cluster ... --service ... --force-new-deployment"
}

output "ecs_service_name" {
  value = aws_ecs_service.bot.name
}
