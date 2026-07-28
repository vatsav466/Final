# Base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies (build tools & C-libraries for Oracle/Nginx/Supervisor if needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    build-essential \
    libaio1 \
    nginx \
    supervisor \
    && rm -rf /lib/apt/lists/*

# Upgrade pip, wheel, and setuptools to fix pkg_resources issue for cx_Oracle
RUN pip install --no-cache-dir --upgrade pip "setuptools<68.0.0" wheel

# Copy backend requirements
COPY backend/requirements.txt /app/backend/requirements.txt

# Install backend requirements using no-build-isolation
RUN if [ -f "/app/backend/requirements.txt" ]; then \
        pip install --no-cache-dir --no-build-isolation -r /app/backend/requirements.txt; \
    fi

# Copy application files
COPY . /app

# Copy supervisor and nginx configs if applicable
# COPY supervisor.conf /etc/supervisor/conf.d/supervisord.conf
# COPY nginx.conf /etc/nginx/sites-available/default

EXPOSE 5378

CMD ["supervisord", "-n"]
