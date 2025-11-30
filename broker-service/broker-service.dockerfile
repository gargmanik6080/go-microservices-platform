FROM golang:1.24-alpine as builder

RUN mkdir /app
COPY . /app

WORKDIR /app

RUN CGO_ENABLED=0 go build -o brokerApp ./cmd/api 
RUN ls -l


FROM alpine:latest

RUN mkdir /app

WORKDIR /app

COPY --from=builder /app/brokerApp .

CMD [ "/app/brokerApp" ]