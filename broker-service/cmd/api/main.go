package main

import (
	"fmt"
	"log"
	"net/http"
)

const webPort = "80"

type Config struct {}

func main() {
	app := Config{}

	log.Printf("Starting broker service on port %s", webPort)

	// defining http server
	srv := &http.Server{
		Addr: fmt.Sprintf(":%s", webPort),
		Handler: app.routes(),
	}

	// starting the server 
	err := srv.ListenAndServe()
	if err != nil {
		log.Panic(err)
	}
}