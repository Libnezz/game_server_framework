# 开发镜像：用于在容器内编译、运行 skynet
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        autoconf \
        git \
        curl \
        ca-certificates \
        vim \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["sleep", "infinity"]
