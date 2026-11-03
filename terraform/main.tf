terraform {
  required_version = ">= 1.6.0"

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

# Read the EC2 instance that is already running.
# This avoids creating a second EC2 instance or changing its networking.
data "aws_instance" "existing_app" {
  instance_id = var.existing_instance_id
}

# ECR repositories used by the GitHub Actions build.
resource "aws_ecr_repository" "backend" {
  name                 = var.backend_ecr_repository
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project_name
    Service = "backend"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = var.frontend_ecr_repository
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project_name
    Service = "frontend"
  }
}

# Role attached to the EXISTING EC2 instance so it can pull images from ECR
# and publish logs through the CloudWatch Agent.
resource "aws_iam_role" "ec2_runtime" {
  name = "${var.project_name}-ec2-runtime"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_readonly" {
  role       = aws_iam_role.ec2_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_agent" {
  role       = aws_iam_role.ec2_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_runtime" {
  name = "${var.project_name}-ec2-runtime-profile"
  role = aws_iam_role.ec2_runtime.name
}

# Terraform creates the instance profile above, but the existing EC2 instance
# is intentionally read-only via data.aws_instance. Attach the profile after
# `terraform apply` using the AWS CLI (commands are provided in README.txt).
# This avoids importing/replacing the existing EC2 instance in Terraform.
data "aws_subnet" "existing_app" {
  id = data.aws_instance.existing_app.subnet_id
}

# CloudWatch log group for application logs. The CloudWatch Agent still
# needs to be installed/configured on EC2 to send Docker logs to this group.
resource "aws_cloudwatch_log_group" "application" {
  name              = "/${var.project_name}/application"
  retention_in_days = 14

  tags = {
    Project = var.project_name
  }
}

# GitHub OIDC provider. If this provider already exists in this AWS account,
# import it into this Terraform state instead of trying to create a duplicate:
# terraform import aws_iam_openid_connect_provider.github \
#   arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = {
    Project = var.project_name
  }
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json

  tags = {
    Project = var.project_name
  }
}

# Least-privilege ECR push permissions for the two repositories.
resource "aws_iam_policy" "github_ecr_push" {
  name        = "${var.project_name}-github-ecr-push"
  description = "Allow the configured GitHub repository to push assessment images to ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = [
          aws_ecr_repository.backend.arn,
          aws_ecr_repository.frontend.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_ecr_push" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_ecr_push.arn
}

