# ECR Repository
resource "aws_ecr_repository" "app" {
  name         = var.project_name
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

# Null resource for Docker build and push
resource "null_resource" "docker_build" {
  triggers = {
    dockerfile_hash = filemd5("../backend/Dockerfile")
    main_py_hash    = filemd5("../backend/main.py")
    requirements_hash = filemd5("../backend/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ../backend
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}
      docker buildx build --platform linux/amd64 --load -t ${var.project_name} .
      docker tag ${var.project_name}:latest ${aws_ecr_repository.app.repository_url}:latest
      docker push ${aws_ecr_repository.app.repository_url}:latest
    EOT
  }

  depends_on = [aws_ecr_repository.app]
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task (Secrets Manager access)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "secrets_manager_policy" {
  name = "${var.project_name}-secrets-manager-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.secrets_manager.arn
        ]
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = var.project_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = var.project_name
      image = "${aws_ecr_repository.app.repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "DEPLOYMENT_TIMESTAMP"
          value = timestamp()
        },
        {
          name  = "CACHE_ENDPOINT"
          value = aws_elasticache_serverless_cache.valkey.endpoint[0].address
        },
        {
          name  = "CACHE_PORT"
          value = tostring(aws_elasticache_serverless_cache.valkey.endpoint[0].port)
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  depends_on = [null_resource.docker_build, aws_elasticache_serverless_cache.valkey]
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.project_name
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.app]
}
