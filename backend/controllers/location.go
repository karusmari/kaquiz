package controllers 

import (
	"kaquiz-backend/database"
	"kaquiz-backend/models"
	"net/http"
	"github.com/gin-gonic/gin"
	"time"
)

func UpdateLocation(c *gin.Context) {

	userID, _ := c.Get("userID") // Get the user ID from the context set by the AuthMiddleware
	var input models.Location
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid coordinates"})
		return
	}

    input.UserID = uint(userID.(float64)) // Set the user ID in the location struct
	input.UpdatedAt = time.Now()

	if err := database.DB.Save(&input).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update location"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Location updated successfully"})
}

func GetFriendsLocations(c *gin.Context) {
	userID, _ := c.Get("userID") // Get the user ID from the context set by the AuthMiddleware

	var locations []models.Location

	// This query retrieves the locations of all accepted friends of the user, excluding the user's own location
	err := database.DB.Table("locations").
		Select("locations.*").
		Joins("join friendships on (friendships.user_id = locations.user_id OR friendships.friend_id = locations.user_id)").
		Where("friendships.status = 'accepted'").
		Where("(friendships.user_id = ? OR friendships.friend_id = ?)", userID, userID).
		Where("locations.user_id != ?", userID). // don't include the user's own location
		Find(&locations).Error

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve friends' locations"})
		return
	}

	c.JSON(http.StatusOK, locations)
}