FROM registry.vizv.com/bcdn-peer
MAINTAINER Wenxuan Zhao <viz@linux.com>

COPY package.json /app-server/
WORKDIR /app-server

RUN mkdir -p /app-server/node_modules \
    && ln -s /app /app-server/node_modules/bcdn \
    && npm install

COPY . /app-server/

ENTRYPOINT ["coffee", "bin/bcdn-server"]
# FIXME: Peer is not event-emitter breaks stuff...
