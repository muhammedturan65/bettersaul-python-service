FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libxml2 libxslt1.1 libffi8 libssl3 curl && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY bettersaul_sources/ ./bettersaul_sources/
COPY scripts/ ./scripts/

EXPOSE 8001

CMD ["uvicorn", "bettersaul_sources.api:app", "--host", "0.0.0.0", "--port", "8001", "--workers", "1"]
