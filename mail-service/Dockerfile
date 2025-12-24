FROM alpine:latest

RUN mkdir /app

WORKDIR /app

COPY mailerApp /app
COPY templates /templates

CMD [ "/app/mailerApp" ]