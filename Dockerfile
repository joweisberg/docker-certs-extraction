FROM alpine
MAINTAINER Jonathan Weisberg <jo.weisberg@gmail.com>

RUN apk update && apk add bash openssl jq

WORKDIR /root
VOLUME /mnt/data

COPY certs-extraction.sh /root/certs-extraction.sh
COPY healthcheck /usr/bin/healthcheck
RUN chmod +x /usr/bin/healthcheck

CMD ["/bin/bash", "/root/certs-extraction.sh"]