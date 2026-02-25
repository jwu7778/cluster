FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    nvidia-container-toolkit \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Environment variable to enable mock data in dev
ENV MOCK_GPU=false

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
