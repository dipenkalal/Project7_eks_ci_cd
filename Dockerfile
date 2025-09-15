FROM node:20-alpine
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev
COPY server.js ./
EXPOSE 3000
CMD ["npm","start"]
