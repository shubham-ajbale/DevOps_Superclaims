# Project Journey – DevOps Assessment

## 1. Understanding the application
The application consists of a FastAPI API, a Celery worker, Redis as the broker/result backend, and an HTML frontend. The main flow is to submit a notification task, receive a task ID, and poll for its state and result.

## 2. Containerization decisions
The API and worker run from the backend image with different startup commands. Redis runs as a separate service. Nginx serves the frontend and proxies API requests. Docker Compose provides service discovery and networking. Environment-specific configuration is supplied through environment variables. A separate production Compose file uses versioned images from Amazon ECR.

## 3. Infrastructure as Code
Terraform was used to provision the AWS resources for the deployment. The tested deployment is in `ap-south-1`. EC2 hosts the production Compose stack and pulls application images from ECR. The EC2 instance role supports ECR image pulls.

## 4. CI/CD design
GitHub Actions builds backend and frontend images, tags them with the commit SHA, and pushes them to ECR. GitHub OIDC is used to assume an AWS IAM role for publishing. The deployment stage connects to EC2 over SSH, logs in to ECR using the instance role, pulls the images, and recreates the Compose services.

## 5. Challenges and fixes
### Docker Compose image variables
The deployment initially failed at the final `docker compose ps` step because `BACKEND_IMAGE` and `FRONTEND_IMAGE` were not available to that command. Exporting both variables in the deployment shell makes them available to subsequent Compose commands.

### Nginx API path
A request to `/notify/` returned an Nginx 404. The deployed proxy routes the backend below `/api/`, so the correct path is `/api/notify/`.

### Required email parameter
A POST request without an email returned HTTP 422. FastAPI identified `email` as a required query parameter. Passing `?email=test@example.com` allowed the request to be accepted.

## 6. End-to-end validation
A task was submitted through the Nginx API route. The task-status endpoint returned:
```json
{
  "task_id": "d573fce3-cc16-4e58-bda5-f2dc4d823895",
  "status": "completed",
  "result": "Task completed: Notification sent to test@example.com"
}
```
This observed result verifies that the task was accepted, processed, and its result retrieved.

## 7. Key learnings
- Containerizing multiple cooperating services.
- Docker Compose service networking and environment configuration.
- Terraform-based infrastructure provisioning.
- GitHub Actions OIDC authentication to AWS.
- Publishing and pulling images from ECR.
- SSH-based deployment to EC2.
- Troubleshooting reverse-proxy paths, API validation, and Compose variable expansion.

## 8. Further improvements
The current Redis service runs in Docker on EC2. A production architecture could use Amazon ElastiCache, private subnets, HTTPS, a domain, centralized log shipping, alarms, backups, and a managed container platform. The CloudWatch log group exists in the environment, but actual log delivery and alerting should be verified before claiming they are complete.

## 9. Evidence to attach
Include screenshots or links showing the successful GitHub Actions run, EC2 container status, frontend, API health response, task submission, and completed task status. Redact account-sensitive details and never include private keys or tokens.
