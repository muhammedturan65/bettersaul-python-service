# BetterSaul Python Source Connector Service

Production-grade Python microservice for scraping **9M+ Turkish legal decisions**, generating real embeddings (multilingual-e5-large), and writing to PostgreSQL + pgvector.

## 🚀 Live Deployment

- **Service**: Deployed on Railway (long-running container)
- **Database**: Railway PostgreSQL + pgvector
- **Redis**: Railway Redis (rate limiting)
- **Web App**: [bettersaul-web](https://github.com/muhammedturan65/bettersaul-web) on Vercel

## 📦 What It Does

1. **Scrapes** 6 Turkish legal sources (Yargıtay, Danıştay, Emsal, AYM, Resmî Gazete, Mevzuat)
2. **Generates embeddings** using multilingual-e5-large (1024-dim) — semantic search ready
3. **Writes** to PostgreSQL + pgvector (HNSW index for fast similarity search)
4. **Exposes REST API** for Next.js admin panel to trigger imports and search

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Vercel (Next.js Web App)                                        │
│  └─ Admin panel → POST /api/import/real → Python service        │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ Railway (Python Service - this repo)                            │
│  ├─ FastAPI: /health /import /search /embed                     │
│  ├─ ImportWorker: async pipeline (concurrent: 5-20)             │
│  ├─ 6 Source Connectors (async httpx + Redis rate limit)        │
│  └─ Embedding backends: e5 / OpenAI / TF-IDF                    │
└────────────────────────────┬────────────────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
    ┌─────────────┐  ┌────────────┐  ┌──────────────┐
    │ 6 Hukuk     │  │ PostgreSQL │  │   Redis      │
    │ Portalları  │  │ +pgvector  │  │ (rate limit) │
    └─────────────┘  └────────────┘  └──────────────┘
```

## 📚 Sources (6 portals, ~9M total decisions)

| Source | URL | Estimated | Rate Limit |
|---|---|---|---|
| Yargıtay | karararama.yargitay.gov.tr | ~4.5M | 20 RPM |
| Danıştay | danistaydergiler.adalet.gov.tr | ~1.2M | 20 RPM |
| Emsal (UYAP) | emsal.uyap.gov.tr | ~2.8M | 20 RPM |
| AYM | anayasa.gov.tr/api | ~65K | 60 RPM |
| Resmî Gazete | resmigazete.gov.tr | ~350K | 30 RPM |
| Mevzuat | mevzuat.gov.tr | ~28K | 60 RPM |

## 🔌 API Endpoints

### Health
```bash
curl https://<your-railway-url>/health
```

### List sources
```bash
curl https://<your-railway-url>/sources
```

### Start import job
```bash
curl -X POST https://<your-railway-url>/import \
  -H "Content-Type: application/json" \
  -d '{
    "source": "yargitay",
    "max_documents": 1000,
    "concurrency": 10,
    "embedding_backend": "auto"
  }'
```

### Job status
```bash
curl https://<your-railway-url>/import/{job_id}
```

### Semantic search
```bash
curl -X POST https://<your-railway-url>/search/semantic \
  -H "Content-Type: application/json" \
  -d '{"query":"işe iade feshin geçersizliği","top_k":20}'
```

## 🛠️ Local Development

```bash
# 1. Install dependencies
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 2. Set environment
cp .env.example .env
# Edit .env with your DATABASE_URL, REDIS_URL

# 3. Run
uvicorn bettersaul_sources.api:app --reload --port 8001

# 4. Test
pytest tests/
```

## 🐳 Docker

```bash
# Build
docker build -t bettersaul-python-service .

# Run
docker run -p 8001:8001 \
  -e DATABASE_URL=$DATABASE_URL \
  -e REDIS_URL=$REDIS_URL \
  bettersaul-python-service
```

## ⏱️ 9M Import Time Estimate

| Source | Decisions | Concurrency | Backend | Time (GPU) | Time (CPU) |
|---|---|---|---|---|---|
| Yargıtay | 4.5M | 10 | e5 | ~12h | ~5 days |
| Danıştay | 1.2M | 10 | e5 | ~3h | ~1.3 days |
| Emsal | 2.8M | 10 | e5 | ~7h | ~3 days |
| AYM | 65K | 5 | e5 | ~10m | ~40m |
| Resmî Gazete | 350K | 10 | e5 | ~1h | ~4h |
| Mevzuat | 28K | 5 | e5 | ~5m | ~20m |
| **Total** | **~9M** | | | **~24h** | **~10 days** |

## 💰 Cost

| Backend | Cost for 9M decisions |
|---|---|
| `e5` (local, GPU) | ~$50 (4h GPU rental) |
| `e5` (local, CPU) | $0 (but 10 days) |
| `openai` (API) | ~$1,170 (9M × 1000 tokens × $0.13/M) |
| `tfidf` (fallback) | $0 (but lower quality) |

## 📁 Project Structure

```
bettersaul-python-service/
├── bettersaul_sources/
│   ├── __init__.py
│   ├── api.py              # FastAPI wrapper
│   ├── connectors.py       # 6 source scrapers
│   ├── db_writer.py        # PostgreSQL + pgvector
│   ├── embeddings.py       # e5 + OpenAI + TF-IDF
│   └── worker.py           # Async import pipeline
├── scripts/
│   ├── init-pgvector.sql
│   └── test_import.py
├── tests/
│   └── test_connectors.py
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── pyproject.toml
└── README.md
```

## 🔐 Environment Variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | ✅ | PostgreSQL connection string |
| `REDIS_URL` | ✅ | Redis connection string |
| `EMBEDDING_BACKEND` | ❌ | `auto` (default), `e5`, `openai`, `tfidf` |
| `OPENAI_API_KEY` | ❌ | Only if `EMBEDDING_BACKEND=openai` |
| `CORS_ORIGINS` | ❌ | Comma-separated allowed origins |
| `DEBUG` | ❌ | `1` for dev mode |
| `WORKERS` | ❌ | Uvicorn workers (default: 1) |

## 📜 License

MIT — BetterSaul Legal Intelligence Platform
