package middleware

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"kaquiz-backend/database" 
	"kaquiz-backend/models"
)

// AuthMiddleware is a Gin middleware function that checks for a valid JWT token in the Authorization header
// and extracts the user ID from the token claims, making it available in the request context for downstream handlers.
func AuthMiddleware(secret []byte) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get the token from the Authorization header
		authHeader := c.GetHeader("Authorization")
		fmt.Printf("🔐 AuthMiddleware: %s %s\n", c.Request.Method, c.Request.URL.Path)

		// checking the format of the header
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			fmt.Printf("⛔ AuthMiddleware: missing or malformed Authorization header\n")
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Authorization header is required"})
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ") // remove the "Bearer " prefix

		// parse and validate the token
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			return secret, nil
		})

		if err != nil || !token.Valid {
			fmt.Printf("⛔ AuthMiddleware: token parse/validation failed: %v, valid=%v\n", err, token != nil && token.Valid)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		// Extract user ID from token claims
		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			fmt.Printf("⛔ AuthMiddleware: token claims are not MapClaims (type=%T)\n", token.Claims)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
			return
		}

		// checking the type of the user_id claim to ensure it's a number (JWT numeric claims are float64)
		userIDFloat, ok := claims["user_id"].(float64)
		if !ok || userIDFloat <= 0 {
			fmt.Printf("⛔ AuthMiddleware: user_id missing or invalid\n")
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid or missing user_id in token"})
			return
		}

		// Check if token has been revoked (jti)
		if jtiStr, ok := claims["jti"].(string); ok && jtiStr != "" {
			var revoked models.RevokedToken
			// if we find a record with this jti in the revoked tokens table, it means the token has been revoked and we should reject it
			if err := database.DB.Where("jti = ?", jtiStr).First(&revoked).Error; err == nil {
				fmt.Printf("⛔ AuthMiddleware: token jti=%s is revoked\n", jtiStr)
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Token has been revoked"})
				return
			}
		}

		// Set user ID as typed uint so the controllers can use it directly
		c.Set("userID", uint(userIDFloat))
		fmt.Printf("✅ AuthMiddleware OK: userID=%d\n", uint(userIDFloat))

		c.Next() // continue to the next handler
	}
}
