FROM alpine:3.6

RUN apk update -qq && apk add --no-cache --virtual wget && \
mkdir blackbox_exporter && cd blackbox_exporter && \
wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.14.0/blackbox_exporter-0.14.0.linux-amd64.tar.gz --no-check-certificate  &&  \
tar xvzf blackbox_exporter-0.14.0.linux-amd64.tar.gz && cd blackbox_exporter-0.14.0.linux-amd64 && mv blackbox_exporter /usr/local/bin/ 

COPY blackbox.yml /etc/blackbox_exporter/config.yml

EXPOSE 9115

WORKDIR /usr/local/bin/
CMD [ "blackbox_exporter","--config.file=/etc/blackbox_exporter/config.yml" ]