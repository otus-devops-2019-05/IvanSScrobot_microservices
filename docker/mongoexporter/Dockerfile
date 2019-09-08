FROM alpine:3.6

RUN apk update -qq && apk add --no-cache --virtual wget && mkdir mongodb-exporter && cd mongodb-exporter && wget https://github.com/percona/mongodb_exporter/releases/download/v0.9.0/mongodb_exporter-0.9.0.linux-amd64.tar.gz --no-check-certificate  && tar xvzf mongodb_exporter-0.9.0.linux-amd64.tar.gz && mv mongodb_exporter /usr/local/bin/

ENV MONGODB_URI='mongodb://:post_db:27017'

WORKDIR /usr/local/bin/
CMD ["mongodb_exporter"]

