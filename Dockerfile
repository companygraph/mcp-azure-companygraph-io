FROM node:26-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --chown=node:node dist/ ./dist/
COPY --chown=node:node favicon.svg ./favicon.svg
COPY --chown=node:node brand.html ./brand.html
COPY --chown=node:node robots.txt ./robots.txt
EXPOSE 8080
USER node
CMD ["node", "node_modules/.bin/companygraph-mcp-deploy", "serve"]
