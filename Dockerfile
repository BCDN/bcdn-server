FROM bcdn-peer
MAINTAINER Wenxuan Zhao <viz@linux.com>

COPY package.json /app-server/
WORKDIR /app-server

USER root
RUN mkdir -p /app-server/node_modules \
    && ln -s /app /app-server/node_modules/bcdn \
    && npm install
USER app

COPY . /app-server/

CMD ["npm", "start"]
