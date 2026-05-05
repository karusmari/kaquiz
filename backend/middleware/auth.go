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
func AuthMiddleware(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get the token from the Authorization header
		authHeader := c.GetHeader("Authorization")
		fmt.Printf("🔐 AuthMiddleware: %s %s\n", c.Request.Method, c.Request.URL.Path)

		// checking the format of the header
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			fmt.Printf("⛔ AuthMiddleware: missing or malformed Authorization header\n")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header is required"})
			c.Abort()
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ") // remove the "Bearer " prefix

		// parse and validate the token
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			return []byte(secret), nil
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

		// Ensure user_id claim exists and is a valid number
		rawID, ok := claims["user_id"]
		if !ok {
			fmt.Printf("⛔ AuthMiddleware: user_id claim missing in token claims\n")
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "user_id missing in token"})
			return
		}

		// Check if token has been revoked (jti)
		rawJTI, _ := claims["jti"]
		if rawJTI != nil {
			if jtiStr, ok := rawJTI.(string); ok && jtiStr != "" {
				var revoked models.RevokedToken
				if err := database.DB.Where("jti = ?", jtiStr).First(&revoked).Error; err == nil {
					fmt.Printf("⛔ AuthMiddleware: token jti=%s is revoked\n", jtiStr)
					c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "token revoked"})
					return
				}
			}
		}

		// JWT numeric claims are float64, so we need to convert it to uint
		userIDFloat, ok := rawID.(float64)
		if !ok || userIDFloat <= 0 {
			fmt.Printf("⛔ AuthMiddleware: user_id claim invalid type=%T value=%v\n", rawID, rawID)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "user_id claim is not a number"})
			return
		}

		// Set user ID as typed uint to avoid float casts in controllers.
		c.Set("userID", uint(userIDFloat))
		fmt.Printf("✅ AuthMiddleware OK: userID=%d\n", uint(userIDFloat))

		c.Next() // continue to the next handler
	}
}
