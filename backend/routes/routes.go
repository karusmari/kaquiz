package routes

import (
	"kaquiz-backend/controllers"
	"github.com/gin-gonic/gin"
	"kaquiz-backend/middleware"
)

// Setup defines the API routes for the application
func Setup(r *gin.Engine) {
	r.POST("/register", controllers.Register)
	r.POST("/login", controllers.Login)

	// Protected routes that need authentication
	protected := r.Group("/api")
	protected.Use(middleware.AuthMiddleware())
	{
		protected.POST("/location", controllers.UpdateLocation)
		protected.POST("/friends/request", controllers.SendFriendRequest)
		protected.GET("/friends/locations", controllers.GetFriendsLocations)
		protected.POST("/friends/accept", controllers.AcceptFriendRequest)
	}
}