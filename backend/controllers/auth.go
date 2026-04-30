package controllers

import (
	"context"
	"kaquiz-backend/database"
	"kaquiz-backend/models"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/joho/godotenv"
	"google.golang.org/api/idtoken"
)

type GoogleLoginInput struct {
	IDToken string `json:"id_token" binding:"required"`
}

func GetSecret() string {
	godotenv.Load()
	return os.Getenv("JWT_SECRET")
}

func GoogleLogin(c *gin.Context) {
	var input GoogleLoginInput

	// Bind the JSON input to the struct
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input"})
		return
	}

	// validate the ID token with Google's OAuth2 API
	payload, err := idtoken.Validate(context.Background(), input.IDToken, "")
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid ID token"})
		return
	}

	aud := payload.Audience
	if aud != os.Getenv("GOOGLE_CLIENT_ID_IOS") && aud != os.Getenv("GOOGLE_CLIENT_ID_ANDROID") && aud != os.Getenv("GOOGLE_WEB_CLIENT_ID") {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid audience in ID token"})
		return
	}

	email := payload.Claims["email"].(string)
	name := payload.Claims["name"].(string)
	avatar := payload.Claims["picture"].(string)

	var user models.User
	if err := database.DB.Where("email = ?", email).First(&user).Error; err != nil {
		// User not found, create a new user with Google avatar and name
		user = models.User{
			Email:  email,
			Name:   name,
			Avatar: avatar,
		}
		database.DB.Create(&user)
	} else {
		// User exists: only set avatar/name from Google if not already present
		updates := map[string]interface{}{}
		if user.Avatar == "" && avatar != "" {
			updates["avatar"] = avatar
		}
		if user.Name == "" && name != "" {
			updates["name"] = name
		}
		if len(updates) > 0 {
			database.DB.Model(&user).Updates(updates)
		}
	}

	// Create JWT token
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": user.ID,
		"exp":     time.Now().Add(time.Hour * 72).Unix(),
	})

	tokenString, err := token.SignedString([]byte(GetSecret()))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"token": tokenString})
}
