# DevOps Assessment – FastAPI, Celery, Redis and Nginx

## Overview
This project containerizes and deploys a background-notification application composed of FastAPI, a Celery worker, Redis, and an Nginx-served HTML frontend. Docker Compose runs the services together. Terraform provisions AWS infrastructure. GitHub Actions builds and publishes Docker images to Amazon ECR and deploys them to EC2.

## Architecture

```text
GitHub repository
      |
GitHub Actions (OIDC to AWS)
      |
Build backend + frontend images
      |
Amazon ECR
      |
SSH deployment to EC2
      |
Nginx :80 --> frontend files
      |
      +-- /api/* --> FastAPI backend
                         |
                      Redis broker
                         |
                     Celery worker
                         |
                  Redis result backend
                         |
                 task status and result
```

Redis is currently a Docker Compose service on EC2, not an AWS-managed Redis service. Amazon ElastiCache is a possible production improvement.

## Components
- **FastAPI:** accepts notification requests and exposes task status.
- **Celery:** processes notification tasks asynchronously.
- **Redis:** broker and result backend.
- **Nginx:** serves the frontend and proxies API requests under `/api/`.
- **Docker Compose:** coordinates application containers.
- **Terraform:** provisions AWS infrastructure.
- **GitHub Actions:** builds, pushes, and deploys versioned images.

## API endpoints
| Purpose | Method and path |
|---|---|
| Health | `GET /api/health/` |
| Submit notification | `POST /api/notify/?email=recipient@example.com` |
| Task status/result | `GET /api/task_status/{task_id}` |

Example:
```bash
curl -X POST "http://localhost/api/notify/?email=test@example.com"
curl "http://localhost/api/task_status/PASTE_TASK_ID_HERE"
```

A deployed end-to-end test returned:
```json
{
  "task_id": "d573fce3-cc16-4e58-bda5-f2dc4d823895",
  "status": "completed",
  "result": "Task completed: Notification sent to test@example.com"
}
```
This confirms the background task flow. The returned text does not independently prove delivery through an external email provider.

## Repository layout
```text
.
├── backend/
│   ├── main.py
│   └── worker.py
├── frontend/
│   └── index.html
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── .github/workflows/deploy.yml
├── Dockerfile
├── docker-compose.yml
├── docker-compose.prod.yml
└── README.md
```
Adjust this tree to match the final repository contents.

## AWS and CI/CD
The deployment was tested in AWS region `ap-south-1`. Backend and frontend images are stored in Amazon ECR. GitHub Actions uses OIDC to assume an AWS IAM role for image publishing. The deployment job connects to EC2 over SSH; the EC2 instance role is used to authenticate to ECR and pull images.

Configure the repository's actual Actions variables/secrets. The names used in this project include `AWS_REGION`, `AWS_ACCOUNT_ID`, `AWS_ROLE_TO_ASSUME`, `EC2_HOST`, `EC2_USER`, and `EC2_SSH_KEY`. Never commit private keys, access keys, passwords, or secret `.tfvars` values.

Pipeline flow:
1. Trigger on a push to the deployment branch.
2. Authenticate to AWS using GitHub OIDC.
3. Build backend and frontend images.
4. Push commit-tagged images to ECR.
5. Connect to EC2 over SSH.
6. Log in to ECR using the EC2 instance role.
7. Pull images and run `docker compose up -d`.
8. Check the health endpoint and container status.

## Operations
Run on EC2:
```bash
cd /home/ubuntu/devops-assignment
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs --tail=100 backend
docker compose -f docker-compose.prod.yml logs --tail=100 worker
docker compose -f docker-compose.prod.yml logs --tail=100 redis
docker compose -f docker-compose.prod.yml logs --tail=100 frontend
```

A CloudWatch log group `/devops-assessment/application` was configured in the environment. Verify that logs are actually being delivered there before claiming centralized log shipping and alerting are fully operational.

## Security and production improvements
- Use IAM roles and OIDC short-lived credentials.
- Restrict inbound EC2 ports; never expose Redis publicly.
- Store the EC2 SSH private key only as a protected GitHub Actions secret.
- Use HTTPS, a domain, private subnets, managed Redis (ElastiCache), log shipping, alarms, backups, and hardened IAM/network policies for production.

## Troubleshooting
- Nginx 404 on `/notify/`: use `/api/notify/` through the configured proxy.
- HTTP 422: `email` is required; pass it as a query parameter.
- Compose says image variables are missing: export `BACKEND_IMAGE` and `FRONTEND_IMAGE` before Compose commands.
- ECR pull denied: check the EC2 role's ECR read permissions and registry login.

## Terraform cleanup
Review the destroy plan carefully; it can delete deployed resources:
```bash
cd terraform
terraform plan -destroy
# Only after reviewing:
terraform destroy
```
