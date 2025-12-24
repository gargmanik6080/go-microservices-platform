FRONT_END_BINARY=frontApp
BROKER_BINARY=brokerApp
AUTH_BINARY=authApp
LOGGER_BINARY=loggerApp
MAILER_BINARY=mailerApp
LISTENER_BINARY=listenerApp

## up
up: 
	@echo "Starting Docker Images..."
	docker-compose up -d
	@echo "Docker images started"

up_build: build_broker build_auth build_logger build_mailer build_listener
	@echo "Stopping Docker images(if running)..."
	docker-compose down
	@echo "Building (when required) and starting docker images..."
	docker-compose up --build -d
	@echo "Docker images built and started!!!"

down:
	@echo "Stopping docker compose..."
	docker-compose down
	@echo "Stopped"

build_all: build_broker build_auth build_logger build_mailer build_listener build_front
	@echo "All binary files built!!!"

build_broker: 
	@echo "Building broker binary..."
	cd broker-service && env GOOS=linux CGO_ENABLED=0 go build -o ${BROKER_BINARY} ./cmd/api
	@echo "Built!!!"

build_logger: 
	@echo "Building logger binary..."
	cd logger-service && env GOOS=linux CGO_ENABLED=0 go build -o ${LOGGER_BINARY} ./cmd/api
	@echo "Built!!!"

build_auth: 
	@echo "Building auth binary..."
	cd authentication-service && env GOOS=linux CGO_ENABLED=0 go build -o ${AUTH_BINARY} ./cmd/api
	@echo "Built!!!"

build_mailer: 
	@echo "Building mailer binary..."
	cd mail-service && env GOOS=linux CGO_ENABLED=0 go build -o ${MAILER_BINARY} ./cmd/api
	@echo "Built!!!"
build_listener: 
	@echo "Building listener binary..."
	cd listener-service && env GOOS=linux CGO_ENABLED=0 go build -o ${LISTENER_BINARY} .
	@echo "Built!!!"



build_front:
	@echo "Building front end binary"
	cd frontend && env CGO_ENABLED=0 go build -o ${FRONT_END_BINARY} ./cmd/web
	@echo "Built!!!"

start: build_front
	@echo "Starting front end"
	cd frontend && ./${FRONT_END_BINARY} &

stop:
	@echo "Stopping front end"
	@-pkill -9 -f "./${FRONT_END_BINARY}"
	@echo "Stopped front end"