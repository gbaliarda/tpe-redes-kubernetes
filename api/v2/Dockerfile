FROM node:latest

WORKDIR /usr/src/app/api

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 8080
CMD ["node", "main.js"]