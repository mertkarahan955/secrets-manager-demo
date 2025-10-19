FROM --platform=linux/amd64 python:3.11-slim

WORKDIR /app

# Gerekli paketleri kopyala ve yükle
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Uygulama kodunu kopyala
COPY main.py .

# Port 8000'i dışarı aç
EXPOSE 8000

# Uygulamayı başlat
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]