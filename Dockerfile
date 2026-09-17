FROM node:22-alpine AS build

WORKDIR /app

ARG NODE_AUTH_TOKEN

COPY package*.json ./

RUN --mount=type=cache,target=/root/.npm \
	echo "@Fiandriananaprime:registry=https://npm.pkg.github.com" > .npmrc \
	&& echo "//npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}" >> .npmrc \
	&& npm ci \
	&& rm -f .npmrc

COPY . .

RUN npm run build


FROM node:22-alpine

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

ARG NODE_AUTH_TOKEN

COPY package*.json ./

RUN --mount=type=cache,target=/root/.npm \
	echo "@Fiandriananaprime:registry=https://npm.pkg.github.com" > .npmrc \
	&& echo "//npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}" >> .npmrc \
	&& npm ci --omit=dev \
	&& rm -f .npmrc

COPY --from=build /app/dist ./dist

EXPOSE 3000

CMD ["node", "dist/server.js"]