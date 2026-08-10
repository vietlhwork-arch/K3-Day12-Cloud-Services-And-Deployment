# ═══════════════════════════════════════════════════════════════════
# CP2 — Production Multi-stage Dockerfile
# ═══════════════════════════════════════════════════════════════════

# ---- Stage 1: Builder ----
FROM python:3.11-slim AS builder
WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Stage 2: Runtime ----
FROM python:3.11-slim AS runtime
WORKDIR /app

COPY --from=builder /install /usr/local
COPY app/ app/
COPY utils/ utils/

# Chạy dưới quyền user thường (non-root)
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8000

# Health check qua HTTP endpoint /health
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import os, urllib.request; port = os.getenv('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health')" || exit 1

# Khởi động ứng dụng, tự động đọc biến $PORT từ môi trường
CMD ["python", "-m", "app.main"]


