# Pre-install validator image. Baked deps; validate.py is mounted from a
# ConfigMap at runtime (chart/finai-studio/files/validate.py is the source of
# truth) so the script can change without an image rebuild.
#
# Build + push to the publisher Artifact Registry, then set
# preinstallValidation.image.repository/tag in values.yaml.
FROM python:3.12-slim AS base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# psycopg2 needs libpq at runtime.
RUN apt-get update \
 && apt-get install -y --no-install-recommends libpq5 \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Baked copy as a fallback; the Helm Job overrides this with the ConfigMap mount.
COPY ../chart/finai-studio/files/validate.py /app/validate.py

# Distroless-style: run as non-root (matches the Job securityContext UID 65532).
USER 65532:65532

ENTRYPOINT ["python", "/app/validate.py"]
