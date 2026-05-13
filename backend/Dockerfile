# Use Python 3.11 slim to keep image size small
FROM python:3.11-slim

# Install system dependencies for Docling and OCR
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your app
COPY . .

# Cloud Run expects the app to listen on the $PORT environment variable
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}