package main

import (
	"log"

	"kaquiz-backend/database"
	"kaquiz-backend/routes"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("warning: backend .env not loaded, falling back to process env")
	}

	database.Connect() // Connect to the database
	r := gin.Default() // set up a server using Gin
	routes.Setup(r)    // set up the API routes
	r.Run(":8080")     // start the server on port 8080
}
