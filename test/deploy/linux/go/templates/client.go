package main

import (
	"fmt"
	"net/http"
	"time"
)

func client() {
	// Create a client.
	client := &http.Client{}

	// Loop forever.
	for {
		// Make a request to the server.
		resp, err := client.Get("http://localhost:8080/transaction")
		if err != nil {
			fmt.Println("Error:", err)
			continue
		}

		fmt.Printf("Server responded with status: %s\n", resp.Status)
		resp.Body.Close()
		time.Sleep(5 * time.Second)
	}
}
