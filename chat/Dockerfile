FROM node:26-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --chown=node:node dist/page.css ./dist/page.css
COPY --chown=node:node favicon.svg ./favicon.svg
COPY --chown=node:node brand.html ./brand.html
EXPOSE 8080
USER node
CMD ["node", "node_modules/.bin/companygraph-chat-deploy", "serve"]
