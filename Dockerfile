# Dockerfile pour le développement local de l'intégration Linux
# Usage: docker-compose up -d

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Dépendances système
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Code source
COPY integration/ ./integration/

EXPOSE 8000

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
