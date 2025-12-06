FROM alpine:latest

RUN mkdir /app

WORKDIR /app

COPY authApp /app

CMD [ "/app/authApp" ]