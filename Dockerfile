FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set work directory
WORKDIR /app

# Install system dependencies (MySQL client libs)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        default-libmysqlclient-dev \
        build-essential \
        pkg-config \
        netcat-openbsd \
        ffmpeg \
        libavformat-dev \
        libavcodec-dev \
        libavdevice-dev \
        libavutil-dev \
        libavfilter-dev \
        libswscale-dev \
        libswresample-dev \
        python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies (lean Docker build — excludes heavy AI/dashboard libs)
COPY requirements.docker.txt /app/
RUN pip install --no-cache-dir -r requirements.docker.txt

# Copy project files
COPY . /app/

# Create necessary directories
RUN mkdir -p /app/staticfiles /app/media

# Make entrypoint executable
RUN chmod +x /app/entrypoint.sh

# Expose port
EXPOSE 8000

# Run startup script
ENTRYPOINT ["/app/entrypoint.sh"]
