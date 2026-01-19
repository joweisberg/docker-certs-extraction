# syntax=docker/dockerfile:1.6

ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETOS

FROM --platform=$TARGETPLATFORM alpine
MAINTAINER Jonathan Weisberg <jo.weisberg@gmail.com>

RUN apk --no-cache --update add bash tzdata openssl jq
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /root
VOLUME /mnt/data

COPY certs-extraction.sh /root/certs-extraction.sh
COPY healthcheck /usr/bin/healthcheck
RUN chmod +x /usr/bin/healthcheck

RUN export DOMAINS=$DOMAINS
CMD ["/bin/bash", "/root/certs-extraction.sh"]