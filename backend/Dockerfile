# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci --legacy-peer-deps

COPY . .
RUN npm run build

# ── Stage 2: Production ───────────────────────────────────────────────────────
FROM node:20-alpine AS production
WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --only=production --legacy-peer-deps && npm cache clean --force

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/src/database ./src/database
COPY scripts/run-migrations.js ./scripts/run-migrations.js
COPY scripts/run-migrations-prod.js ./scripts/run-migrations-prod.js

# Create uploads directory
RUN mkdir -p uploads

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3000/api/v1/health || exit 1

# Run migrations then start the server
CMD ["sh", "-c", "node scripts/run-migrations-prod.js && node dist/src/main"]
