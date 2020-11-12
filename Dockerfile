FROM mcr.microsoft.com/powershell:lts-ubuntu-18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN \
    # APT default to yes
    echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes && \
    apt-get update && \
    apt-get upgrade

WORKDIR /
COPY ./init.ps1 ./
COPY ./run.ps1 ./

CMD ["pwsh","./init.ps1"]