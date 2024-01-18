package main

import (
	"fmt"
	"github.com/gin-gonic/gin"
	"time"
)

func main() {
	go client()
	//paste license key code snippet here

	transactions := make(chan string)

	go func() {
		for {
			// Generate a new transaction.
			transaction := fmt.Sprintf("Transaction generated at %s", time.Now().Format(time.RFC3339))
			transactions <- transaction
			time.Sleep(time.Second)
		}
	}()

	// Create a Gin router.

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
