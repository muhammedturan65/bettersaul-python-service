FROM python:3.12-slim

# System deps (no build-essential needed for runtime-only)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libxml2 \
    libxslt1.1 \
    libffi8 \
    libssl3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements first (better layer caching)
COPY requirements.txt .

# Install Python dependencies
# Note: sentence-transformers + torch are HUGE (~2.5GB)
# For Railway/Vercel deployment, we use TF-IDF backend by default
# To use e5, set EMBEDDING_BACKEND=e5 and install manually:
#   pip install sentence-transformers torch
RUN pip install --no-cache-dir \
    fastapi==0.115.0 \
    uvicorn[standard]==0.30.6 \
    pydantic==2.9.2 \
    httpx[http2]==0.27.2 \
    beautifulsoup4==4.12.3 \
    lxml==5.3.0 \
    asyncpg==0.29.0 \
    "redis[hiredis]==5.0.8" \
    python-dateutil==2.9.0 \
    tenacity==9.0.0 \
    python-dotenv==1.0.1 \
    structlog==24.4.0 \
    || echo "Some deps failed to install"

# Copy source
COPY bettersaul_sources/ ./bettersaul_sources/
COPY scripts/ ./scripts/

EXPOSE 8001

# Use lighter worker count for Railway
CMD ["uvicorn", "bettersaul_sources.api:app", "--host", "0.0.0.0", "--port", "8001", "--workers", "1"]
