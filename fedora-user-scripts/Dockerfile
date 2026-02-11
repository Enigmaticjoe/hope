FROM fedora:43

LABEL maintainer="Project CHIMERA" \
      description="Fedora User Scripts — Web UI for managing and scheduling bash scripts" \
      version="1.0.0"

# Install system dependencies
RUN dnf install -y --setopt=install_weak_deps=False \
        python3 \
        python3-pip \
        cronie \
        bash \
        procps-ng \
        && dnf clean all

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py cron_manager.py ./
COPY templates/ templates/
COPY static/ static/
COPY seed-scripts/ /seed-scripts/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Persistent volume for user scripts
VOLUME ["/data/scripts"]

ENV FUS_SCRIPTS_DIR=/data/scripts \
    FUS_PORT=9855

EXPOSE 9855

ENTRYPOINT ["/entrypoint.sh"]
