package routes

import (
	"kaquiz-backend/controllers"
	"github.com/gin-gonic/gin"
)

// Setup defines the API routes for the application
func Setup(r *gin.Engine) {
	r.POST("/register", controllers.Register)
	//r.POST("/login", controllers.Login)
}