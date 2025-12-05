FROM alpine:latest

RUN mkdir /app

WORKDIR /app

COPY brokerApp /app

CMD [ "/app/brokerApp" ]