# 9router — build from source + apply patches
# Multi-stage: build → patch middleware → final image

FROM node:22-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo ca-certificates lsof git \
    && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
# Source patches A/1/4/G already applied in source files
RUN npm run build

# ── Stage 2: patch middleware then package ──
FROM node:22-slim AS patched
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo ca-certificates lsof \
    && rm -rf /var/lib/apt/lists/*

# Copy built output
COPY --from=builder /app ./

# Patch I — middleware: find + patch dynamically
RUN MW=$(find . -name "middleware.js" 2>/dev/null | head -1) && \
    echo "Found middleware: $MW" && \
    sed -i 's|"/api/cli-tools/antigravity-mitm",||' "$MW" && \
    ! grep -q '/api/cli-tools/antigravity-mitm' "$MW" && \
    echo "Patch I ✓" || (echo "Patch I failed" && exit 1)

EXPOSE 20128 443
CMD ["node", "node_modules/next/dist/bin/next", "start"]
