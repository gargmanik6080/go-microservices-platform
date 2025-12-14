FROM alpine:latest

RUN mkdir /app

WORKDIR /app

COPY frontApp /app

CMD [ "/app/frontApp" ]