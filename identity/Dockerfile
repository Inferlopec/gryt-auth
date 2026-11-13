FROM node:22-alpine@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a AS builder
WORKDIR /app

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --ignore-engines

COPY . .
RUN yarn build

FROM builder AS test-runner
RUN yarn add --dev --ignore-engines socket.io-client@4.8.1

FROM node:22-alpine@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a AS deps
WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --production --ignore-engines

FROM node:22-alpine@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a

RUN addgroup -g 1001 -S gryt \
  && adduser -S gryt -u 1001 -G gryt -h /app -s /sbin/nologin

WORKDIR /app
ENV NODE_ENV=production

COPY --from=deps --chown=gryt:gryt /app/node_modules ./node_modules
COPY --from=builder --chown=gryt:gryt /app/package.json ./package.json
COPY --from=builder --chown=gryt:gryt /app/dist ./dist

RUN mkdir -p /app/data && chown gryt:gryt /app/data

USER gryt
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "dist/index.js"]
