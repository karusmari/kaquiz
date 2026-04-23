package main

import (
	"github.com/gin-gonic/gin"
	"kaquiz-backend/database"
	"kaquiz-backend/routes"
)

func main() {
	database.Connect() // Connect to the database
	r := gin.Default() // set up a server using Gin
	routes.Setup(r) // set up the API routes
	r.Run(":8080") // start the server on port 8080
}