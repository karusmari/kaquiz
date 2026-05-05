package controllers

import (
	"fmt"
	"kaquiz-backend/database"
	"kaquiz-backend/models"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func SearchUsers(c *gin.Context) {
	userID, ok := c.Get("userID")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	currentUserID, ok := userID.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

	query := strings.TrimSpace(c.Query("email")) // keep existing param name for compatibility
	if query == "" {
		c.JSON(http.StatusOK, []gin.H{})
		return
	}

	pattern := "%" + strings.ToLower(query) + "%"

	var users []struct {
		ID     uint   `json:"id"`
		Name   string `json:"name"`
		Email  string `json:"email"`
		Avatar string `json:"avatar"`
	}

	err := database.DB.Table("users").
		Select("id, name, email, avatar").
		Where("id != ?", currentUserID).
		Where("LOWER(email) LIKE ? OR LOWER(name) LIKE ?", pattern, pattern).
		Where(
			"NOT EXISTS (SELECT 1 FROM friendships WHERE ((friendships.user_id = ? AND friendships.friend_id = users.id) OR (friendships.user_id = users.id AND friendships.friend_id = ?)))",
			currentUserID,
			currentUserID,
		).
		Order("name ASC, email ASC").
		Limit(10).
		Scan(&users).Error
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search users"})
		return
	}

	if len(users) == 0 {
		c.JSON(http.StatusOK, []gin.H{})
		return
	}

	c.JSON(http.StatusOK, users)
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

func DeclineInvites(c *gin.Context) {
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

	// Only allow decline if the invite was addressed to current user
	result := database.DB.Where("id = ? AND friend_id = ?", input.FriendID, currentUserID).Delete(&models.Friendship{})

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decline friend request"})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Friend request not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Friend request declined"})
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

	friendIDStr := c.Param("id") // Get the friend ID from the URL parameter
	var friendID uint
	if _, err := fmt.Sscanf(friendIDStr, "%d", &friendID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid friend id"})
		return
	}

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
		ID     uint   `json:"user_id"`
		Name   string `json:"name"`
		Email  string `json:"email"`
		Avatar string `json:"avatar"`
	}

	// Query all accepted friendships and join with users table
	err := database.DB.Table("users").
		Select("users.id, users.name, users.email, users.avatar").
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
		ID           uint   `json:"id"`
		SenderID     uint   `json:"sender_id"`
		SenderName   string `json:"sender_name"`
		SenderEmail  string `json:"sender_email"`
		SenderAvatar string `json:"sender_avatar"`
		Status       string `json:"status"`
	}

	// Query all pending friendships where current user is the recipient
	err := database.DB.Table("friendships").
		Select("friendships.id, friendships.user_id as sender_id, users.name as sender_name, users.email as sender_email, users.avatar as sender_avatar, friendships.status").
		Joins("join users on users.id = friendships.user_id").
		Where("friendships.friend_id = ? AND friendships.status = 'pending'", currentUserID).
		Scan(&invites).Error

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve pending invites"})
		return
	}

	c.JSON(http.StatusOK, invites)
}
