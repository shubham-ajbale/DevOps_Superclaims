variable "aws_region" {
  description = "AWS region containing the existing EC2 instance"
  type        = string
  default     = "ap-south-1"
}

variable "existing_instance_id" {
  description = "Existing EC2 instance ID from the AWS console screenshot"
  type        = string
  default     = "i-08cbca2c4e07a00b0"
}

variable "project_name" {
  description = "Prefix used for AWS resource names"
  type        = string
  default     = "devops-assessment"
}

variable "backend_ecr_repository" {
  description = "ECR repository name for FastAPI and Celery image"
  type        = string
  default     = "devops-assignment-backend"
}

variable "frontend_ecr_repository" {
  description = "ECR repository name for Nginx frontend image"
  type        = string
  default     = "devops-assignment-frontend"
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repository"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to assume the GitHub Actions role"
  type        = string
  default     = "main"
}
