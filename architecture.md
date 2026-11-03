# DevOps Assessment – System Architecture

## Architecture diagram

```mermaid
flowchart TB
    Dev[Developer] -->|Push code / Pull Request| GH[GitHub Repository]

    subgraph CICD["CI/CD – GitHub Actions"]
        WF[GitHub Actions Workflow]
        BUILD[Build Docker Images]
        PUSH[Push Images]
        DEPLOY[SSH deployment to EC2]
        WF --> BUILD --> PUSH --> DEPLOY
    end

    GH -->|Trigger workflow| WF

    subgraph AWS["AWS – ap-south-1"]
        OIDC[IAM Role for GitHub Actions]
        ECR[(Amazon ECR<br/>Backend and Frontend Images)]
        subgraph EC2["EC2 Instance – Ubuntu"]
            COMPOSE[Docker Compose]
            NGINX[Nginx – Frontend / Reverse Proxy]
            API[FastAPI Backend]
            REDIS[(Redis)]
            WORKER[Celery Worker]

            COMPOSE --> NGINX
            COMPOSE --> API
            COMPOSE --> REDIS
            COMPOSE --> WORKER

            NGINX -->|Serve frontend| USER[End User / Browser]
            USER -->|HTTP request| NGINX
            NGINX -->|/api/* reverse proxy| API
            API -->|Enqueue background task| REDIS
            WORKER -->|Fetch task| REDIS
            WORKER -->|Execute notification task| WORKER
            API -->|Task status response| NGINX
        end
        TF[Terraform – Infrastructure as Code]
        IAM[EC2 IAM Instance Role]
        CW[CloudWatch Logs<br/>(verify log shipping)]
        TF -->|Provision / manage infrastructure| EC2
        IAM -.->|Instance permissions| EC2
        EC2 -.->|Application logs, if configured| CW
    end

    PUSH -->|Docker image push| ECR
    DEPLOY -->|Pull latest tagged images<br/>and restart Compose services| EC2
    OIDC -.->|Assume role via OIDC| WF
    ECR -->|Images pulled by EC2| COMPOSE
```

## Request and deployment flow

1. A developer pushes code to the GitHub repository.
2. GitHub Actions runs the CI/CD workflow.
3. The workflow builds the backend and frontend Docker images.
4. GitHub Actions authenticates to AWS using its IAM role and pushes images to Amazon ECR.
5. The workflow connects to the EC2 instance over SSH and deploys the tagged images using Docker Compose.
6. Nginx serves the frontend and forwards `/api/*` requests to FastAPI.
7. FastAPI places background tasks in Redis; the Celery worker consumes and processes them.
8. The frontend polls the task-status endpoint to display the task result.

## Deployment details

- AWS Region: `ap-south-1`
- EC2 public endpoint: `http://3.110.136.224`
- Backend health endpoint: `http://3.110.136.224/api/health/`
- Backend image: `443568785279.dkr.ecr.ap-south-1.amazonaws.com/devops-assignment-backend`
- Frontend image: `443568785279.dkr.ecr.ap-south-1.amazonaws.com/devops-assignment-frontend`

## Notes

- Redis is currently deployed as a Docker Compose service on EC2; it is not Amazon ElastiCache.
- CloudWatch log group `/devops-assessment/application` was identified in the project configuration. Confirm that a log shipping agent or other forwarding mechanism is installed and sending logs before claiming centralized logging is operational.
- Terraform is the infrastructure-as-code layer. The exact resources managed by Terraform should match the committed `.tf` files.
- The diagram describes the known deployment flow. Adjust component names if the committed Compose or workflow files use different service names.
