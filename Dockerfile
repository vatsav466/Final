FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    supervisor \
    build-essential \
    python3-dev \
    gcc \
    g++ \
    libpq-dev \
    libssl-dev \
    libffi-dev \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy project
COPY . /app

# Upgrade pip and install compatible build tools
RUN python -m pip install --upgrade pip && \
    pip install --no-cache-dir \
    setuptools==80.9.0 \
    wheel

# Install backend requirements
RUN if [ -f "/app/backend/requirements.txt" ]; then \
    pip install --no-cache-dir -r /app/backend/requirements.txt; \
fi

# Install local package
RUN if [ -d "/app/backend/UrdhvaBase" ]; then \
    cd /app/backend/UrdhvaBase && \
    pip install --no-cache-dir .; \
fi

# Supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80 5378

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
