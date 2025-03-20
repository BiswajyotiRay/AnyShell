# Use Ubuntu 20.04 base image
FROM ubuntu:20.04

# Set environment variables for non-interactive setup and locale
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    TERM=xterm

# Install essential packages including tmate dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    locales \
    python3 \
    python3-pip \
    python3-apt \
    python3-dev \
    python3-venv \
    openssh-server \
    curl \
    wget \
    git \
    jq \
    ca-certificates \
    sudo \
    unzip \
    htop \
    neofetch \
    speedtest-cli \
    xz-utils && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean && \
    apt-get -y autoremove

# Copy the start.sh script into the container
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Ensure correct working directory
WORKDIR /app
COPY . /app

# Expose necessary ports
EXPOSE 22 80 8888 8080 443

# Start all scripts
CMD ["/bin/bash", "-c", "/start.sh"]