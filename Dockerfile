FROM mcr.microsoft.com/powershell:lts-ubuntu-18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN \
    apt-get -y update && \
    apt-get -y upgrade

WORKDIR /
COPY rootfs /

CMD ["pwsh","./init.ps1"]