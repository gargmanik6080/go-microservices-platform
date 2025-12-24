FROM golang:latest AS builder

WORKDIR /app

COPY go.mod go.sum* ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o frontApp ./cmd/web

FROM alpine:latest

RUN mkdir /app

WORKDIR /app

COPY --from=builder /app/frontApp /app/

CMD [ "/app/frontApp" ]