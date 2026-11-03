from celery import Celery
import time
import os

# Read Redis URL from environment variable
REDIS_URL = os.getenv(
    "REDIS_URL",
    "redis://redis:6379/0"
)

# Configure Celery
celery = Celery(
    "worker",
    broker=REDIS_URL,
    backend=REDIS_URL,
)


@celery.task
def write_log_celery(message: str):
    time.sleep(10)

    with open("log_celery.txt", "a") as f:
        f.write(f"{message}\n")

    return f"Task completed: {message}"
