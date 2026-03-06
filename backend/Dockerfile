# Stage 1: Build the React frontend
FROM node:18-alpine AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm ci || npm install
COPY frontend/ ./
RUN npm run build

# Stage 2: Build the FastAPI backend and serve frontend
FROM python:3.9-slim

WORKDIR /app

# Install dependencies (nvidia-smi is usually host-mounted, but we install toolkit just in case)
RUN apt-get update && apt-get install -y --no-install-recommends \
    nvidia-container-toolkit \
    && rm -rf /var/lib/apt/lists/*

# Copy backend requirements and install
COPY backend/requirements.txt ./backend/
RUN pip install --no-cache-dir -r backend/requirements.txt

# Copy backend source
COPY backend/ ./backend/

# Copy frontend build from stage 1 into the location expected by main.py
COPY --from=frontend-builder /app/frontend/build ./frontend/build

WORKDIR /app/backend

# Environment variable to enable mock data in dev
ENV MOCK_GPU=false

# Expose the port
EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
