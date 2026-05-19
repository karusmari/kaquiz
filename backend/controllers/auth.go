package controllers

import (
	"context"
	"kaquiz-backend/database"
	"kaquiz-backend/models"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"google.golang.org/api/idtoken"
)

type GoogleLoginInput struct {
	IDToken string `json:"id_token" binding:"required"`
}

func GetSecret() []byte {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		panic("JWT_SECRET environment variable is not set")
	}
 	return []byte(secret)
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

	// Check the audience to ensure the token is meant for our app
	aud := payload.Audience
	if aud != os.Getenv("GOOGLE_CLIENT_ID_IOS") && aud != os.Getenv("GOOGLE_CLIENT_ID_ANDROID") && aud != os.Getenv("GOOGLE_WEB_CLIENT_ID") {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid audience in ID token"})
		return
	}

	// Extract user info from the token claims
	email := payload.Claims["email"].(string)
	name := payload.Claims["name"].(string)
	avatar := payload.Claims["picture"].(string)

	// Check if a user with this email already exists in the database
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

	// Create JWT token with a jti (unique id) so it can be revoked
	jti := uuid.NewString()
	// Create JWT token
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": user.ID,
		"exp":     time.Now().Add(time.Hour * 72).Unix(),
		"jti":     jti,
	})

	// Sign the token with the secret key
	tokenString, err := token.SignedString([]byte(GetSecret()))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"token": tokenString})
}

// SignOut revokes the current token (by jti) so it can't be used again
func SignOut(c *gin.Context) {
	// Extract token string from Authorization header
	authHeader := c.GetHeader("Authorization")
	if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header is required"})
		return
	}
	// strip "bearer " prefix to get the actual token string
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")

	// Parse token and check for the validity
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		return GetSecret(), nil
	})
	if err != nil || !token.Valid {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
		return
	}
    
	// convert the generic token claims to a map so we can access the jti
	// we are unpacking the "box" so Go can actually read the key-value pairs inside the token claims 	
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid token claims"})
		return
	}

	// reading the claim: extract the unique token ID (jti) from the claims and ensure it's a valid string
	jtiStr, ok := claims["jti"].(string)
	if !ok || jtiStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid jti"})
		return
	}

	// Create a record of this jti in the revoked tokens table so it can't be used again
	// this puts the token's unique ID onto the "blacklist" in my database
	revoked := models.RevokedToken{
		JTI:       jtiStr,
		RevokedAt: time.Now(),
	}
	if err := database.DB.Create(&revoked).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to revoke token"})
		return
	}

	// confirm the client that they have been signed out successfully
	c.JSON(http.StatusOK, gin.H{"message": "Signed out"})
}
