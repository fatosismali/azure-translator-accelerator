# Development container for Azure Translator Accelerator

FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    vim \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Create non-root user
RUN useradd -m -s /bin/bash appuser

# Set working directory
WORKDIR /app

# Switch to non-root user
USER appuser

# Install common Python tools
RUN pip install --user --upgrade pip setuptools wheel

CMD ["/bin/bash"]

