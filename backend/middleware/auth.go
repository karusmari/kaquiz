package middleware

import (
	"fmt"
	"kaquiz-backend/controllers"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get the token from the Authorization header
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header is required"})
			c.Abort()
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ") // remove the "Bearer " prefix

		// parse and validate the token
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			return []byte(controllers.GetSecret()), nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
			c.Abort()
			return
		}

		claimUserID, ok := claims["user_id"]
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "user_id missing in token"})
			c.Abort()
			return
		}

		var parsedUserID uint
		switch v := claimUserID.(type) {
		case float64:
			if v <= 0 {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid user id in token"})
				c.Abort()
				return
			}
			parsedUserID = uint(v)
		case int:
			if v <= 0 {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid user id in token"})
				c.Abort()
				return
			}
			parsedUserID = uint(v)
		case uint:
			if v == 0 {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid user id in token"})
				c.Abort()
				return
			}
			parsedUserID = v
		default:
			c.JSON(http.StatusUnauthorized, gin.H{"error": fmt.Sprintf("Unsupported user id type: %T", claimUserID)})
			c.Abort()
			return
		}

		// Set user ID as typed uint to avoid float casts in controllers.
		c.Set("userID", parsedUserID)

		c.Next() // continue to the next handler
	}
}
