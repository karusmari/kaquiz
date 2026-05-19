package controllers

import (
	"errors"
	"kaquiz-backend/database"
	"kaquiz-backend/models"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// search users by email
func SearchUsers(c *gin.Context) {
	currentUserID, err := GetUserIDFromContext(c)
	if err != nil {
		if err.Error() == "unauthorized" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

	// Get the search query from the query parameters, trim whitespace, and check if it's empty
	query := strings.TrimSpace(c.Query("email"))
	if query == "" {
		c.JSON(http.StatusOK, []gin.H{})
		return
	}

	// use a case-insensitive search pattern
	pattern := "%" + strings.ToLower(query) + "%"

	// users struct to hold the search results, only selecting the fields we need for the frontend to display the search results
	var users []struct {
		ID     uint   `json:"id"`
		Name   string `json:"name"`
		Email  string `json:"email"`
		Avatar string `json:"avatar"`
	}

	// Query the database for users matching the search pattern, excluding the current user and existing friends
	err = database.DB.Table("users").
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

	// if no users found, return an empty array instead of null
	if len(users) == 0 {
		c.JSON(http.StatusOK, []gin.H{})
		return
	}

	c.JSON(http.StatusOK, users)
}

// send a friend request to another user
func SendInvites(c *gin.Context) {
	currentSenderID, err := GetUserIDFromContext(c)
	if err != nil {
		if err.Error() == "unauthorized" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

	friendID, err := ParseUintParam(c, "user_id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user_id"})
		return
	}

	// Verify recipient exists in the database
	var friend models.User
	if err := database.DB.First(&friend, friendID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Check if friendship already exists (pending or accepted)
	existingFriendship, err := FindFriendshipBetween(currentSenderID, friendID)
	if err == nil {
		if existingFriendship.Status == "pending" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Friend request already pending"})
			return
		} else if existingFriendship.Status == "accepted" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Already friends"})
			return
		}
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check friendship"})
		return
	}

	// create a friend request
	friendship := models.Friendship{
		UserID:   currentSenderID,
		FriendID: friendID,
		Status:   "pending",
	}

	// create the friendship record in the database
	if err := database.DB.Create(&friendship).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send friend request"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Friend request sent successfully"})
}

// accept a friend request
func AcceptInvites(c *gin.Context) {
	currentUserID, err := GetUserIDFromContext(c)
	if err != nil {
		if err.Error() == "unauthorized" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

	friendshipID, err := resolveFriendshipID(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input"})
		return
	}

	// finding the friend request from the database and updating its status to "accepted"
	// checking if the 'friend_id' matches the user's ID to ensure that the user is accepting a request sent to them, not a request they sent
	result := database.DB.Model(&models.Friendship{}).
		Where("id = ? AND friend_id = ?", friendshipID, currentUserID).
		Update("status", "accepted")

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to accept friend request"})
		return
	}

	// If no rows were affected, it means the friend request was not found or the user is not the recipient
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Friend request not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Friend request accepted successfully"})

}

// decline a friend request
func DeclineInvites(c *gin.Context) {
	currentUserID, err := GetUserIDFromContext(c)
	if err != nil {
		if err.Error() == "unauthorized" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

	friendshipID, err := resolveFriendshipID(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input"})
		return
	}

	// Only allow decline if the invite was addressed to current user
	result := database.DB.Where("id = ? AND friend_id = ?", friendshipID, currentUserID).Delete(&models.Friendship{})

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

func resolveFriendshipID(c *gin.Context) (uint, error) {
	var input struct {
		FriendshipID uint `json:"friendship_id"`
	}

	if err := c.ShouldBindJSON(&input); err == nil && input.FriendshipID != 0 {
		return input.FriendshipID, nil
	}

	pathValue := strings.TrimSpace(c.Param("user_id"))
	if pathValue == "" {
		pathValue = strings.TrimSpace(c.Param("id"))
	}
	if pathValue == "" {
		return 0, errors.New("missing friendship id")
	}

	parsedID, err := strconv.ParseUint(pathValue, 10, 64)
	if err != nil {
		return 0, err
	}

	return uint(parsedID), nil
}

func DeleteFriend(c *gin.Context) {
	currentUserID, err := GetUserIDFromContext(c)
	if err != nil {
		if err.Error() == "unauthorized" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

	friendID, err := ParseUintParam(c, "id")
	if err != nil {
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
	currentUserID, err := GetUserIDFromContext(c)
	if err != nil {
		if err.Error() == "unauthorized" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
			return
		}
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
	err = database.DB.Table("users").
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
	currentUserID, err := GetUserIDFromContext(c)
	if err != nil {
		if err.Error() == "unauthorized" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
			return
		}
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
	err = database.DB.Table("friendships").
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
