# --- Stage 1: Build Frontend ---
FROM node:20-alpine AS frontend
WORKDIR /frontend

# Cache dependencies layer
COPY frontend/package*.json ./
RUN npm ci

# Copy source and build static bundle
COPY frontend/ ./
RUN npm run build

# --- Stage 2: Final Runtime ---
FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app/backend/UrdhvaBase:/app/backend/api_manager:/app/backend

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    supervisor \
    gcc \
    build-essential \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libpangocairo-1.0-0 \
    libgobject-2.0-0 \
    libcairo2 \
    libgdk-pixbuf2.0-0 \
    libffi-dev \
    shared-mime-info \
    fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

    
# Install Python dependencies
COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && grep -v -i '^cx_Oracle' /app/requirements.txt > /app/requirements.filtered.txt \
    && pip install --no-cache-dir -r /app/requirements.filtered.txt \
    && pip install --no-cache-dir "uvicorn[standard]" \
    && pip install --no-cache-dir \
        fastapi \
        redis \
        sqlalchemy \
        pydantic \
        pydantic-settings \
        cryptography \
        elasticsearch \
        pymongo \
        motor \
        jinja2 \
        mangum \
        numpy \
        pytz \
        textx \
        python-multipart

# Copy Application Files
COPY backend /app/backend
COPY --from=frontend /frontend/dist /usr/share/nginx/html

# Drop-in replacement for removed snakecase package
RUN printf 'import re\n\ndef convert(s):\n    return re.sub(r"(?<!^)(?=[A-Z])", "_", s).lower()\n' > /app/backend/UrdhvaBase/snakecase.py

# Copy Configuration Files (Nginx left completely untouched as requested)
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Only publish 5378 to the host (8001 is kept internal for Supervisord -> Uvicorn)
EXPOSE 5378

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
