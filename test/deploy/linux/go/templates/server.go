package main

import (
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
)

// importCommand
// importGinCommand

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
