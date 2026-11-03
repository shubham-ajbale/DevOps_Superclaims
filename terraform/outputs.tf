output "existing_ec2_instance_id" {
  description = "Existing EC2 instance managed as a data source"
  value       = data.aws_instance.existing_app.id
}

output "existing_ec2_public_ip" {
  description = "Public IPv4 address of the existing EC2 instance"
  value       = data.aws_instance.existing_app.public_ip
}

output "existing_ec2_private_ip" {
  description = "Private IPv4 address of the existing EC2 instance"
  value       = data.aws_instance.existing_app.private_ip
}

output "existing_ec2_instance_type" {
  description = "Instance type reported by AWS"
  value       = data.aws_instance.existing_app.instance_type
}

output "existing_ec2_vpc_id" {
  description = "VPC containing the existing EC2 instance"
  value       = data.aws_subnet.existing_app.vpc_id
}

output "existing_ec2_subnet_id" {
  description = "Subnet containing the existing EC2 instance"
  value       = data.aws_instance.existing_app.subnet_id
}

output "backend_ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "github_actions_role_arn" {
  description = "Set this as the AWS_ROLE_TO_ASSUME GitHub Actions secret"
  value       = aws_iam_role.github_actions.arn
}

output "cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.application.name
}

output "ec2_instance_profile_name" {
  description = "IAM instance profile to attach to the existing EC2 instance"
  value       = aws_iam_instance_profile.ec2_runtime.name
}
