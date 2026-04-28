package routes

import (
	"kaquiz-backend/controllers"
	"github.com/gin-gonic/gin"
	"kaquiz-backend/middleware"
)

// Setup defines the API routes for the application
func Setup(r *gin.Engine) {
	r.POST("/auth", controllers.GoogleLogin)

	// Protected routes that need authentication
	protected := r.Group("/api")
	protected.Use(middleware.AuthMiddleware())
	{
		protected.GET("/users/search", controllers.SearchUsers)
		
		protected.POST("/location", controllers.UpdateLocation)
		
		protected.POST("/invites/:user_id", controllers.SendInvites)
		protected.POST("/invites/:user_id/accept", controllers.AcceptInvites)
		//protected.POST("/invites/:user_id/decline", controllers.DeclineInvites)

		protected.GET("/friends", controllers.GetFriendsLocations)
		//protected.DELETE("/friends/:id", controllers.DeleteFriend)
	}
}