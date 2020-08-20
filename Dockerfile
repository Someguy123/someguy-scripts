FROM ubuntu:20.04

# Very basic Ubuntu 18.04 Dockerfile
# Intended for testing Someguy's Scripts on a blank
# Ubuntu installation easily.
#
# Usage:
# ~/someguy-scripts $ docker build -t sgscripts .
# ~/someguy-scripts $ docker run -it sgscripts

RUN apt-get update -qy && \
    apt-get install -qy curl wget jq && \
    apt-get clean -qy

COPY . /root/someguy-scripts

RUN cp -v /root/someguy-scripts/extras/utils/* /usr/bin/

WORKDIR /root/someguy-scripts

ENTRYPOINT [ "bash" ]
