package controllers

import (
	"fmt"
	"kaquiz-backend/database"
	"kaquiz-backend/models"
	"net/http"

	"github.com/gin-gonic/gin"
)

func SearchUsers(c *gin.Context) {
	email := c.Query("email") //get the email query parameter from the request

	var user models.User
	if err := database.DB.Where("email = ?", email).First(&user).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"id":    user.ID,
		"email": user.Email,
	})
}

func SendInvites(c *gin.Context) {
	senderID, ok := c.Get("userID") // Get the sender's user ID from the context set by the AuthMiddleware
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	currentSenderID, ok := senderID.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

	friendIDStr := c.Param("user_id") // Get the recipient user ID from the URL path

	// Parse recipient user ID
	var friendID uint
	if _, err := fmt.Sscanf(friendIDStr, "%d", &friendID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user_id"})
		return
	}

	// Verify recipient exists
	var friend models.User
	if err := database.DB.First(&friend, friendID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Check if friendship already exists (pending or accepted)
	var existingFriendship models.Friendship
	if err := database.DB.Where(
		"(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)",
		currentSenderID, friendID, friendID, currentSenderID,
	).First(&existingFriendship).Error; err == nil {
		// Friendship exists
		if existingFriendship.Status == "pending" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Friend request already pending"})
		} else if existingFriendship.Status == "accepted" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Already friends"})
		}
		return
	}

	// create a friend request
	friendship := models.Friendship{
		UserID:   currentSenderID,
		FriendID: friendID,
		Status:   "pending",
	}

	if err := database.DB.Create(&friendship).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send friend request"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Friend request sent successfully"})
}

func AcceptInvites(c *gin.Context) {
	userID, ok := c.Get("userID") // Get the user's ID from the context set by the AuthMiddleware
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	currentUserID, ok := userID.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

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
		Where("id = ? AND friend_id = ?", input.FriendID, currentUserID).
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

func DeleteFriend(c *gin.Context) {
	userID, ok := c.Get("userID") // Get the current user's ID from the context
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	currentUserID, ok := userID.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

	friendID := c.Param("id") // Get the friend ID from the URL parameter

	// Delete the friendship (either direction)
	result := database.DB.Where(
		"(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)",
		currentUserID, friendID, friendID, currentUserID,
	).Delete(&models.Friendship{})

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete friend"})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Friendship not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Friend deleted successfully"})
}

func ListFriends(c *gin.Context) {
	userID, ok := c.Get("userID") // Get the current user's ID from the context
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	currentUserID, ok := userID.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

	var friends []struct {
		ID    uint   `json:"user_id"`
		Name  string `json:"name"`
		Email string `json:"email"`
	}

	// Query all accepted friendships and join with users table
	err := database.DB.Table("users").
		Select("users.id, users.name, users.email").
		Joins("join friendships on (friendships.friend_id = users.id OR friendships.user_id = users.id)").
		Where("friendships.status = 'accepted'").
		Where("(friendships.user_id = ? OR friendships.friend_id = ?)", currentUserID, currentUserID).
		Where("users.id != ?", currentUserID). // don't include self
		Scan(&friends).Error

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve friends"})
		return
	}

	c.JSON(http.StatusOK, friends)
}

func GetPendingInvites(c *gin.Context) {
	userID, ok := c.Get("userID") // Get the current user's ID from the context
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	currentUserID, ok := userID.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

	var invites []struct {
		ID          uint   `json:"id"`
		SenderID    uint   `json:"sender_id"`
		SenderName  string `json:"sender_name"`
		SenderEmail string `json:"sender_email"`
		Status      string `json:"status"`
	}

	// Query all pending friendships where current user is the recipient
	err := database.DB.Table("friendships").
		Select("friendships.id, friendships.user_id as sender_id, users.name as sender_name, users.email as sender_email, friendships.status").
		Joins("join users on users.id = friendships.user_id").
		Where("friendships.friend_id = ? AND friendships.status = 'pending'", currentUserID).
		Scan(&invites).Error

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve pending invites"})
		return
	}

	c.JSON(http.StatusOK, invites)
}
