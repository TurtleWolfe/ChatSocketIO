# FROM node:10.13-alpine

## Stage 1 (production base)
FROM node:12.16.1-stretch-slim as base
# set this with shell variables at build-time.
# If they aren't set, then not-set will be default.
ARG CREATED_DATE=April2020
ARG SOURCE_COMMIT=not-set
# labels from https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL org.opencontainers.image.authors=TurtleWolfe.com
LABEL org.opencontainers.image.created=$CREATED_DATE
LABEL org.opencontainers.image.revision=$SOURCE_COMMIT
LABEL org.opencontainers.image.title="MERNDauth"
LABEL org.opencontainers.image.url=https://hub.docker.com/TurtleWolfe/MERNDauth
LABEL org.opencontainers.image.source=https://github.com/TurtleWolf/MERNDauth
LABEL org.opencontainers.image.licenses=MIT
LABEL com.TurtleWolfe.nodeversion=$NODE_VERSION
ENV NODE_ENV=production
EXPOSE 3000
COPY .bashrc /home/node
WORKDIR /opt
COPY ["package.json", "package-lock.json*", "npm-shrinkwrap.json*", "./"]
RUN apt-get update && mkdir this_app && chown -R node:node . && apt-get install curl -y && npm config list
# we use npm ci here so only the package-lock.json file is used
RUN npm config list \
    && npm ci \
    && npm cache clean --force
# ENTRYPOINT [ "/sbin/tini", "--"]
CMD ["node", "./bin/www"]

## Stage 2 (development)
# we don't COPY in this stage because for dev you'll bind-mount anyway
# this saves time when building locally for dev via docker-compose
# docker build -t api:dev .
FROM base as dev
ENV NODE_ENV development
ENV PATH=/opt/node_modules/.bin:$PATH
WORKDIR /opt
USER node
RUN npm install --only=development --silent
WORKDIR /opt/this_app
# WORKDIR /node
# ENTRYPOINT [ "../node_modules/nodemon/bin/nodemon.js", "--"]
CMD ["../node_modules/nodemon/bin/nodemon.js", "server.js", "--inspect=0.0.0.0:9229"]

## Stage 3 (copy in source)
# This gets our source code into builder for use in next two stages
# It gets its own stage so we don't have to copy twice
# this stage starts from the first one and skips the last two
FROM base as source
WORKDIR /opt/this_app
COPY . .
# RUN rm -r proxy

# ## Stage 4 (testing)
# # use this in automated CI
# # it has prod and dev npm dependencies
# # In 18.09 or older builder, this will always run
# # In BuildKit, this will be skipped by default 
# FROM source as test
# ENV NODE_ENV=development
# ENV PATH=/opt/node_modules/.bin:$PATH
# # this copies all dependencies (prod+dev)
# COPY --from=dev /opt/node_modules /opt/node_modules
# # run linters as part of build
# # be sure they are installed with devDependencies
# RUN eslint . 
# # run unit tests as part of build
# RUN npm test
# # run integration testing with docker-compose later
# WORKDIR /opt/this_app
# CMD ["npm", "run", "int-test"] 

# ## Stage 5 (security scanning and audit)
# FROM test as audit
# RUN npm audit
# # aqua microscanner, which needs a token for API access
# # note this isn't super secret, so we'll use an ARG here
# # https://github.com/aquasecurity/microscanner
# ARG MICROSCANNER_TOKEN
# ADD https://get.aquasec.com/microscanner /
# RUN chmod +x /microscanner
# RUN apk add --no-cache ca-certificates && update-ca-certificates
# RUN /microscanner $MICROSCANNER_TOKEN --continue-on-failure

## Stage 6 (default, production)
# this will run by default if you don't include a target
# it has prod-only dependencies
# In BuildKit, this is skipped for dev and test stages
FROM source as prod
# FROM base as prod
ENV NODE_ENV=production
ENV PATH=/opt/node_modules/.bin:$PATH
USER node
WORKDIR /opt/this_app
CMD ["node", "server.js"]
# docker build -t api:dev .

# CMD node server.js