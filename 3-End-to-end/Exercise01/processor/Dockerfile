FROM python:3.11-slim

WORKDIR /app

# Copiar dependencias e instalarlas
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar script
COPY processor.py .

# Ejecutar script
CMD ["python", "-u", "processor.py"]
