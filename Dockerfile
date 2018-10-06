FROM ubuntu:bionic

# Very basic Ubuntu 18.04 Dockerfile
# Intended for testing Someguy's Scripts on a blank
# Ubuntu installation easily.
#
# Usage:
# ~/someguy-scripts $ docker build -t sgscripts .
# ~/someguy-scripts $ docker run -it sgscripts

COPY . /root/someguy-scripts

WORKDIR /root/someguy-scripts

ENTRYPOINT [ "bash" ]
