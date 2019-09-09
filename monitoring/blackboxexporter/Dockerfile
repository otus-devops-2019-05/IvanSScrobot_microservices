FROM alpine:3.6

RUN apk update -qq && apk add --no-cache --virtual wget && \
mkdir /bin/blackbox_exporter && cd /bin/blackbox_exporter && \
wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.14.0/blackbox_exporter-0.14.0.linux-amd64.tar.gz --no-check-certificate  &&  \
tar xvzf blackbox_exporter-0.14.0.linux-amd64.tar.gz && rm -f *.tar.gz

COPY blackbox.yml /etc/blackbox_exporter/config.yml

EXPOSE 9115
ENTRYPOINT [ "/bin/blackbox_exporter" ]
CMD [ "--config.file=/etc/blackbox_exporter/config.yml" ]
