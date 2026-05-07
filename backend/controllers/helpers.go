package controllers

import (
	"fmt"

	"kaquiz-backend/database"
	"kaquiz-backend/models"

	"github.com/gin-gonic/gin"
)

// GetUserIDFromContext extracts and validates the userID stored in Gin context by the auth middleware.
// Returns the userID and nil error on success, otherwise an error describing the problem.
func GetUserIDFromContext(c *gin.Context) (uint, error) {
	userID, ok := c.Get("userID")
	if !ok {
		return 0, fmt.Errorf("unauthorized")
	}

	currentUserID, ok := userID.(uint)
	if !ok {
		return 0, fmt.Errorf("invalid user id")
	}

	return currentUserID, nil
}

// ParseUintParam parses a uint ID from URL path parameter and returns an error when invalid.
func ParseUintParam(c *gin.Context, param string) (uint, error) {
	paramStr := c.Param(param)
	var id uint
	if _, err := fmt.Sscanf(paramStr, "%d", &id); err != nil {
		return 0, fmt.Errorf("invalid %s", param)
	}
	return id, nil
}

// FindFriendshipBetween returns the friendship record between two users in either direction.
// If not found, returns (nil, gorm.ErrRecordNotFound).
func FindFriendshipBetween(a, b uint) (*models.Friendship, error) {
	var existing models.Friendship
	err := database.DB.Where(
		"(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)",
		a, b, b, a,
	).First(&existing).Error

	if err != nil {
		return nil, err
	}
	return &existing, nil
}
