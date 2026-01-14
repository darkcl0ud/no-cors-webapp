locals {
  api_name = "no-cors-webapp-api"
  azs      = toset(["a", "b"])
  cidr     = "10.0.0.0/16"
  region   = split(":", aws_vpc.api_server.arn)[3]
  endpoints = toset([
    "ecs-agent",
    "ecs-telemetry",
    "ecs",
    "ecr.api",
    "ecr.dkr",
    "logs",
  ])
}

data "aws_ecr_repository" "api_server" {
  name = "no-cors-webapp/be"
}

resource "aws_vpc" "api_server" {
  cidr_block           = local.cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = local.api_name
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.api_server.id
}

resource "aws_cloudfront_vpc_origin" "api_server" {
  depends_on = [aws_internet_gateway.gw]
  vpc_origin_endpoint_config {
    name                   = local.api_name
    arn                    = aws_lb.api_server.arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
}

resource "aws_subnet" "alb_subnets" {
  for_each          = local.azs
  vpc_id            = aws_vpc.api_server.id
  cidr_block        = cidrsubnet(local.cidr, 8, index(tolist(local.azs), each.value))
  availability_zone = "${local.region}${each.value}"
}

resource "aws_subnet" "server_subnets" {
  for_each          = local.azs
  vpc_id            = aws_vpc.api_server.id
  cidr_block        = cidrsubnet(local.cidr, 8, index(tolist(local.azs), each.value) + length(local.azs))
  availability_zone = "${local.region}${each.value}"
}

resource "aws_subnet" "endpoint_subnets" {
  for_each          = local.azs
  vpc_id            = aws_vpc.api_server.id
  cidr_block        = cidrsubnet(local.cidr, 8, index(tolist(local.azs), each.value) + (length(local.azs) * 2))
  availability_zone = "${local.region}${each.value}"
}

resource "aws_security_group" "api_server_alb" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.api_server.id
}

resource "aws_security_group" "api_server" {
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "TCP"
    security_groups = [aws_security_group.api_server_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.api_server.id
}

resource "aws_security_group_rule" "api_server_alb" {
  type                     = "egress"
  security_group_id        = aws_security_group.api_server_alb.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "TCP"
  source_security_group_id = aws_security_group.api_server.id
}

resource "aws_lb" "api_server" {
  name               = local.api_name
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.api_server_alb.id]
  subnets            = [for subnet in aws_subnet.alb_subnets : subnet.id]
}

resource "aws_lb_target_group" "api_server" {
  name                              = local.api_name
  target_type                       = "ip"
  port                              = 80
  protocol                          = "HTTP"
  vpc_id                            = aws_vpc.api_server.id
  load_balancing_cross_zone_enabled = true
  health_check {
    enabled  = true
    path     = "/api/health"
    port     = 80
    protocol = "HTTP"
    matcher  = 204
  }
}

resource "aws_security_group" "endpoints" {
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "TCP"
    security_groups = [aws_security_group.api_server.id]
  }

  vpc_id = aws_vpc.api_server.id
}

resource "aws_vpc_endpoint" "aws_services" {
  for_each          = local.endpoints
  vpc_id            = aws_vpc.api_server.id
  service_name      = "com.amazonaws.${local.region}.${each.value}"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.endpoints.id
  ]

  subnet_ids = [for subnet in aws_subnet.endpoint_subnets : subnet.id]

  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.api_server.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_vpc.api_server.default_route_table_id]
}

resource "aws_lb_listener" "api_server" {
  load_balancer_arn = aws_lb.api_server.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_server.arn
  }
}

resource "aws_iam_policy" "ecr_pull" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

data "aws_iam_policy_document" "trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "api_server" {
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
}

resource "aws_iam_role_policy_attachment" "ecr_pull" {
  role       = aws_iam_role.api_server.name
  policy_arn = aws_iam_policy.ecr_pull.arn
}

resource "aws_ecs_task_definition" "api_server" {
  depends_on               = [aws_iam_role_policy_attachment.ecr_pull]
  family                   = local.api_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.api_server.arn
  container_definitions = jsonencode([
    {
      name      = local.api_name
      image     = data.aws_ecr_repository.api_server.repository_url
      essential = true
      portMappings = [
        {
          containerPort = 80
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/api/health || exit 1"]
        startPeriod = 30
      }
      environment = [
        {
          name = "GIN_MODE",
          value = "release"
        }
      ]
    },
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

resource "aws_ecs_cluster" "api_server" {
  name = local.api_name
}

resource "aws_ecs_service" "api_server" {
  depends_on = [
    aws_lb_listener.api_server,
    aws_vpc_endpoint.aws_services
  ]
  name            = local.api_name
  cluster         = aws_ecs_cluster.api_server.id
  task_definition = aws_ecs_task_definition.api_server.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.api_server.arn
    container_name   = local.api_name
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets         = [for subnet in aws_subnet.server_subnets : subnet.id]
    security_groups = [aws_security_group.api_server.id]
  }
}

