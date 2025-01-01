#provider has aws creds omitted because this code assumes that a terraform.tfvars will be availabe with aws_profile and aws_shared_credentials_file values filled in
#variables file has aws region 
#run command 'tofu show' after build to see the final output from line 208 for the external app URL to the juiceshop.
#be sure to either create an s3 bucket with the same name from the variables file or change the bucket name there. The s3_permisisons.json will need updating if you intend to use it for a new bukcet, be sure to change the bucket name
terraform {
  backend "s3" {
    bucket = var.aws_bucket
    key    = "terraform/state"
    region = var.aws_region
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "juice-shop-vpc" 
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "juice-shop-public-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# (in)Security Groups - allowing ingress/egress from all public sources is by design for the juiceshop
resource "aws_security_group" "alb" {
  name        = "juice-shop-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "super insecure port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "allow all the traffic from everywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs" {
  name        = "juice-shop-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "container port to 3000, mapped external to alb port 80"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "allow all the traffic from everywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer
#internal is set to false and left exposed to outside traffic as part of juiceshop deployment
resource "aws_lb" "main" {
  name               = "juice-shop-alb"
  internal           = false            
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = aws_subnet.public[*].id
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "juice_shop" {
  name        = "juice-shop-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    matcher             = "200,302"
  }
}

#port 80 vs https/443 is on purpose, it's part of the juiceshop deployment design
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.juice_shop.arn
  }
}

# ECS Resources
resource "aws_ecs_cluster" "main" {
  name = "juice-shop-cluster"
  
    setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "juice_shop" {
  family                   = "juice-shop"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = 256
  memory                  = 512

  container_definitions = jsonencode([
    {
      name  = "juice-shop"
      image = "bkimminich/juice-shop:latest"
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "juice_shop" {
  name            = "juice-shop-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.juice_shop.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.juice_shop.arn
    container_name   = "juice-shop"
    container_port   = 3000
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

output "juice_shop_url" {
  value = "http://${aws_lb.main.dns_name}"
}