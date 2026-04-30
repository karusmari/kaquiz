package routes

import (
	"kaquiz-backend/controllers"
	"kaquiz-backend/middleware"

	"github.com/gin-gonic/gin"
)

// Setup defines the API routes for the application
func Setup(r *gin.Engine) {
	r.POST("/auth", controllers.GoogleLogin)

	// Protected routes that need authentication
	protected := r.Group("/api")
	protected.Use(middleware.AuthMiddleware())
	{
		protected.PUT("/users", controllers.UpdateUserProfile)
		protected.GET("/users/me", controllers.GetMyProfile)
		protected.GET("/users/search", controllers.SearchUsers)

		protected.POST("/location", controllers.UpdateLocation)

		protected.POST("/invites/:user_id", controllers.SendInvites)
		protected.POST("/invites/:user_id/accept", controllers.AcceptInvites)
		//protected.POST("/invites/:user_id/decline", controllers.DeclineInvites)
		protected.GET("/invites/pending", controllers.GetPendingInvites)

		protected.GET("/friends", controllers.GetFriendsLocations)
		protected.GET("/friends/list", controllers.ListFriends)
		protected.DELETE("/friends/:id", controllers.DeleteFriend)
	}
}
