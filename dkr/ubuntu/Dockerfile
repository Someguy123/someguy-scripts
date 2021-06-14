FROM ubuntu:focal

RUN sed -Ei 's/archive.ubuntu.com/se1.apt-cache.privex.io/g' /etc/apt/sources.list && \
    sed -Ei 's#security.ubuntu.com#se1.apt-cache.privex.io/ubuntu-security#g' /etc/apt/sources.list

WORKDIR /app

COPY . /app

CMD [ "bash" ]
