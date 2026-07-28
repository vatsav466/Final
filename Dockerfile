FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    supervisor \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app

# Install UrdhvaBase package (with fallback to ignore missing snakecase==1.0.1 pin)
RUN if [ -d "/app/backend/UrdhvaBase" ]; then \
        cd /app/backend/UrdhvaBase && \
        (sed -i 's/snakecase==1.0.1/snakecase/g' setup.py 2>/dev/null || true) && \
        pip install --no-cache-dir . || pip install --no-deps --no-cache-dir . ; \
    fi

# Install backend requirements
RUN if [ -f "/app/backend/requirements.txt" ]; then \
        pip install --no-cache-dir -r /app/backend/requirements.txt ; \
    fi

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80 5378

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
