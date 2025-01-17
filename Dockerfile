FROM alpine:latest

RUN apk add --no-cache \
    git \
    curl \
    bash

RUN adduser -D -u 1001 builder

COPY ./*.sh /home/builder/

RUN chmod +x /home/builder/*.sh

WORKDIR /home/builder

USER builder

ENTRYPOINT ["/home/builder/entrypoint.sh"]
