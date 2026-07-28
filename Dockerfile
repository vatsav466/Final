FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system dependencies, C compilers, and required libraries for Python build extensions
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
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app

# Upgrade pip, setuptools, and wheel first
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install UrdhvaBase package
RUN if [ -d "/app/backend/UrdhvaBase" ]; then \
        cd /app/backend/UrdhvaBase && \
        (sed -i 's/snakecase==1.0.1/snakecase/g' setup.py 2>/dev/null || true) && \
        pip install --no-cache-dir . || pip install --no-deps --no-cache-dir . ; \
    fi

# Install backend requirements with fallback option if specific pinned versions fail on Python 3.12
RUN if [ -f "/app/backend/requirements.txt" ]; then \
        pip install --no-cache-dir -r /app/backend/requirements.txt || \
        pip install --no-cache-dir --use-deprecated=legacy-resolver -r /app/backend/requirements.txt ; \
    fi

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80 5378

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
