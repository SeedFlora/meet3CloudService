# API Net Web Lab: Node.js 22 (Alpine) tanpa framework + driver pg.
# Image dasar dari Amazon ECR Public (mirror resmi Docker Official Images);
# compose.yaml bisa menggantinya lewat build arg LAB_REGISTRY.
ARG LAB_REGISTRY=public.ecr.aws/docker/library
FROM ${LAB_REGISTRY}/node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

# Salin manifest dulu supaya layer dependency di-cache: build ulang setelah
# mengubah server.js tidak perlu mengunduh ulang paket npm.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

COPY server.js ./

# Jalan sebagai user biasa "node" (uid 1000), bukan root.
USER node
EXPOSE 3000
CMD ["node", "server.js"]
