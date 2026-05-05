package controllers

import (
	"kaquiz-backend/database"
	"kaquiz-backend/models"
	"net/http"
	"time"

	"fmt"

	"github.com/gin-gonic/gin"
)

func UpdateLocation(c *gin.Context) {

	userID, ok := c.Get("userID") // Get the user ID from the context set by the AuthMiddleware
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	currentUserID, ok := userID.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

	var input models.Location
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid coordinates"})
		return
	}

	input.UserID = currentUserID // Set the user ID in the location struct
	input.UpdatedAt = time.Now()

	if err := database.DB.Save(&input).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update location"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Location updated successfully"})
}

func GetFriendsLocations(c *gin.Context) {
	fmt.Println(">>> GetFriendsLocations CALLED")
	userID, ok := c.Get("userID") // Get the user ID from the context set by the AuthMiddleware
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	currentUserID, ok := userID.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user id"})
		return
	}

	//changing the response struct to include the friend's name and avatar, which are needed for the frontend
	// to display the markers on the map with the correct information
	type FriendLocationResponse struct {
		UserID    uint      `json:"user_id"`
		Latitude  float64   `json:"latitude"`
		Longitude float64   `json:"longitude"`
		UpdatedAt time.Time `json:"updated_at"`
		Name      string    `json:"name"`   // Tuleb User tabelist
		Avatar    string    `json:"avatar"` // Tuleb User tabelist
	}

	var results []FriendLocationResponse

	// This query retrieves the locations of all accepted friends of the user, excluding the user's own location
	err := database.DB.Table("locations").
		Select("locations.user_id, locations.latitude, locations.longitude, locations.updated_at, users.name, users.avatar").
		Joins("JOIN users ON users.id = locations.user_id").
		Where("locations.user_id IN (?)",
			database.DB.Table("friendships").
				Select("CASE WHEN user_id = ? THEN friend_id ELSE user_id END", currentUserID).
				Where("status = 'accepted' AND (user_id = ? OR friend_id = ?)", currentUserID, currentUserID),
		).
		Scan(&results).Error

	if err != nil {
		fmt.Printf("Error retrieving friends' locations: %v\n", err) // Log the error for debugging
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve friends' locations"})
		return
	}
	fmt.Printf("Retrieved %d friends' locations for user %d\n", len(results), currentUserID) // Log the number of locations retrieved
	for _, res := range results {
		fmt.Printf("Friend ID: %d, Name: %s, Avatar: %s, Lat: %f, Lng: %f\n", res.UserID, res.Name, res.Avatar, res.Latitude, res.Longitude) // Log each friend's location details
	}

	c.JSON(http.StatusOK, results)
}
