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
    unixodbc \
    unixodbc-dev \
    odbcinst \
    && rm -rf /var/lib/apt/lists/*

# WeasyPrint runtime dependencies (Pango/Cairo/GLib stack)
# NOTE: libgobject-2.0-0 is NOT a real package name — the libgobject-2.0.so.0
# shared library ships inside libglib2.0-0. Installing the wrong/non-existent
# name is why WeasyPrint couldn't find it at runtime.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libpangocairo-1.0-0 \
    libglib2.0-0 \
    libcairo2 \
    libgdk-pixbuf2.0-0 \
    libffi-dev \
    shared-mime-info \
    fonts-liberation \
    && ldconfig \
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
        python-multipart \
        aiohttp \
        xlsxwriter

# Copy Application Files
COPY backend /app/backend
COPY --from=frontend /frontend/dist /usr/share/nginx/html

# Drop-in replacement for removed snakecase package
RUN printf 'import re\n\ndef convert(s):\n    return re.sub(r"(?<!^)(?=[A-Z])", "_", s).lower()\n' > /app/backend/UrdhvaBase/snakecase.py

# NOTE: we deliberately do NOT `pip install -e` the UrdhvaBase package here.
# Its setup.py pins snakecase==1.0.1, which has been pulled from PyPI, so an
# editable/packaged install fails at build time. PYTHONPATH already makes
# `import urdhva_base` (and `python3 -m urdhva_base`) resolve correctly via
# plain path lookup, using the local snakecase.py shim above instead.

# Copy Configuration Files (Nginx left completely untouched as requested)
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Only publish 5378 to the host.
# Internal-only ports (not published, proxied by nginx):
#   8001 -> urdhva_base.restapi:app  (full backend aggregator: /docs, /api/*)
#   8002 -> cache_gateway.cache_api_actions:app (/api_cache/*)
EXPOSE 5378

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
