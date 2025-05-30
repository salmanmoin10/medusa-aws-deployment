resource "aws_ecr_repository" "medusa" {
  name                 = "${var.project_name}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-backend"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "medusa" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-logs"
    Environment = var.environment
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  tags = {
    Name        = "${var.project_name}-cluster"
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "medusa" {
  family                   = "${var.project_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "${var.project_name}-backend"
      image = "${aws_ecr_repository.medusa.repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 9000
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "DATABASE_TYPE"
          value = "postgres"
        },
        {
          name  = "DATABASE_URL"
          value = "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.endpoint}:5432/medusa"
        },
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "NPM_CONFIG_PRODUCTION"
          value = "false"
        }
      ]
      
      secrets = [
        {
          name      = "JWT_SECRET"
          valueFrom = aws_ssm_parameter.jwt_secret.arn
        },
        {
          name      = "COOKIE_SECRET"
          valueFrom = aws_ssm_parameter.cookie_secret.arn
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.medusa.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-task-definition"
    Environment = var.environment
  }
}

resource "aws_ecs_service" "medusa" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.medusa.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.medusa.arn
    container_name   = "${var.project_name}-backend"
    container_port   = 9000
  }

  depends_on = [aws_lb_listener.medusa]

  tags = {
    Name        = "${var.project_name}-service"
    Environment = var.environment
  }
}