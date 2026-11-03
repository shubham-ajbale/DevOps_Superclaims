# Local Setup Instructions

## Prerequisites
Install Git, Docker Engine or Docker Desktop, and the Docker Compose plugin.

Verify:
```bash
docker --version
docker compose version
```

## 1. Clone the repository
```bash
git clone https://github.com/shubham-ajbale/DevOps_Superclaims.git
cd DevOps_Superclaims
```
Use the current repository URL if it changes.

## 2. Configure environment variables
Review the variables referenced by `docker-compose.yml`, `backend/main.py`, and `backend/worker.py`.

If the repository contains `.env.example`, copy and edit it:
```bash
cp .env.example .env
```
Do not commit `.env`. If no example file exists, define the variables required by the Compose file. Inside containers, the Redis broker/result-backend address should use the Redis Compose service hostname, not `localhost`.

## 3. Build and start
```bash
docker compose build
docker compose up -d
docker compose ps
```

## 4. View logs
```bash
docker compose logs -f
docker compose logs -f backend
docker compose logs -f worker
docker compose logs -f redis
docker compose logs -f frontend
```
Use `Ctrl+C` to stop following logs; containers continue running.

## 5. Test the API
The Nginx proxy exposes the API under `/api/`.

Health:
```bash
curl -i http://localhost/api/health/
```

Submit a task (the `email` query parameter is required):
```bash
curl -i -X POST "http://localhost/api/notify/?email=test@example.com"
```

Copy the returned `task_id` and check it:
```bash
curl "http://localhost/api/task_status/PASTE_TASK_ID_HERE"
```
If it is still pending, wait briefly and query again.

## 6. Stop the stack
```bash
docker compose down
```
To also delete named-volume data (irreversible for that local data), use only when you intentionally want a clean reset:
```bash
docker compose down -v
```

## 7. Rebuild after changes
```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

## Troubleshooting
- **Port 80 is busy:** stop the other local web server or change the frontend host-port mapping.
- **Nginx 404:** use `/api/notify/` and `/api/task_status/...` through the configured proxy.
- **HTTP 422:** include the required email query parameter.
- **Task stays pending:** inspect `docker compose logs --tail=100 worker` and `redis`; verify broker/result-backend settings match.
- **Missing image variables:** local development should use `docker-compose.yml`; production Compose may require ECR image variables.

## Production deployment
Production deployment is performed by GitHub Actions, which builds and pushes images to ECR and deploys them to EC2. These local instructions do not require running Terraform or destroying cloud infrastructure.
