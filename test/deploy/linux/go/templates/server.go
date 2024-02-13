package main

import (
	"fmt"
	"time"
	"net/http"
	"github.com/gin-gonic/gin"
)

//importCommand
//importGinCommand

func main() {
	go client()

	//codeSnippet

	
	transactions := make(chan string)

	go func() {
		for {
			// Generate a new transaction.
			transaction := fmt.Sprintf("Transaction generated at %s", time.Now().Format(time.RFC3339))
			transactions <- transaction
			time.Sleep(time.Second)
		}
	}()

	//routerSnippet



	router.GET("/transaction", func(c *gin.Context) {
		transaction := <-transactions
		c.JSON(200, gin.H{
			"transaction": transaction,
		})
	})
	if err != nil {
		fmt.Println("Error starting Gin server:", err)
	}

	router.Run()
}

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
