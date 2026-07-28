# Step 1: Base Python & Nginx Environment
FROM python:3.12-slim

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system dependencies, Nginx, and Supervisor
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    supervisor \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy project files
COPY . /app

# Install UrdhvaBase package
RUN if [ -d "/app/backend/UrdhvaBase" ]; then \
        cd /app/backend/UrdhvaBase && pip install --no-cache-dir . ; \
    fi

# Install general backend dependencies if a requirements file exists
RUN if [ -f "/app/backend/requirements.txt" ]; then \
        pip install --no-cache-dir -r /app/backend/requirements.txt ; \
    fi

# Copy Supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose standard web/Nginx port
EXPOSE 80

# Start Supervisor to run all services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
