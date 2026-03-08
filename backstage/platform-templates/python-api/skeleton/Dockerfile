# Build com diferentes versões Python
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim

# Metadata
LABEL maintainer="Cielo CASD"
LABEL python.version="${PYTHON_VERSION}"

# Criar usuário não-root
RUN useradd -m -u 1000 app

WORKDIR /app

# Instalar dependências de build e Python
COPY requirements.txt .
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libffi-dev \
    && pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt \
    && apt-get purge -y --auto-remove gcc libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Copiar código
COPY --chown=app:app . .

# Mudar para usuário não-root
USER app

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/actuator/health')" || exit 1

EXPOSE 8080

CMD ["python", "main.py"]
