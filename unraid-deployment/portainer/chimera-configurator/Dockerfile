# Chimera Media Stack Configurator
# Lightweight container for auto-configuring media services
FROM python:3.11-alpine

LABEL maintainer="Project Chimera"
LABEL description="Auto-configure Sonarr, Radarr, Prowlarr, and other media services"

# Install required packages
RUN apk add --no-cache \
    bash \
    docker-cli \
    curl

# Create app directory
WORKDIR /app

# Copy the configurator script
COPY media_configurator.py /app/
COPY entrypoint.sh /app/

RUN chmod +x /app/media_configurator.py /app/entrypoint.sh

# Config persistence
VOLUME ["/config"]

# Environment variables
ENV APPDATA_PATH=/appdata
ENV CONFIG_PATH=/config

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["--auto"]
