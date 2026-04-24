package controllers

import (
	"kaquiz-backend/database"
	"kaquiz-backend/models"
	"net/http"
	"github.com/gin-gonic/gin"
)

func SendFriendRequest(c *gin.Context) {
	senderID, _ := c.Get("userID") // Get the sender's user ID from the context set by the AuthMiddleware
	var input struct {
		Email string `json:"email"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input"})
		return
	}
    
	// find a user by email to send the friend request to
	var friend models.User
	if err := database.DB.Where("email = ?", input.Email).First(&friend).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// create a friend request
	friendship := models.Friendship{
		UserID:   uint(senderID.(float64)),
		FriendID: friend.ID,
		Status:     "pending",
	}

	if err := database.DB.Create(&friendship).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send friend request"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Friend request sent successfully"})
}

func AcceptFriendRequest(c *gin.Context) {
	userID, _ := c.Get("userID") // Get the user's ID from the context set by the AuthMiddleware
	var input struct {
		FriendID uint `json:"friendship_id"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input"})
		return
	}

	// finding the friend request from the database and updating its status to "accepted"
	// checking if the 'friend_id' matches the user's ID to ensure that the user is accepting a request sent to them, not a request they sent
	result := database.DB.Model(&models.Friendship{}).
		Where("id = ? AND friend_id = ?", input.FriendID, userID).
		Update("status", "accepted")

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to accept friend request"})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Friend request not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Friend request accepted successfully"})

}