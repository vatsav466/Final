FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y \
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

# Install compatible build tools
RUN pip install --no-cache-dir \
    --upgrade pip \
    "setuptools<81" \
    wheel

# Install backend dependencies
RUN if [ -f "/app/backend/requirements.txt" ]; then \
    pip install --no-cache-dir -r /app/backend/requirements.txt; \
fi

# Install local package
RUN if [ -d "/app/backend/UrdhvaBase" ]; then \
    cd /app/backend/UrdhvaBase && \
    pip install --no-cache-dir .; \
fi

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80 5378

CMD ["/usr/bin/supervisord","-c","/etc/supervisor/conf.d/supervisord.conf"]
