package models

import "time"

// RevokedToken stores JWT IDs (jti) of revoked tokens
type RevokedToken struct {
    ID        uint      `gorm:"primaryKey" json:"-"`
    JTI       string    `gorm:"uniqueIndex" json:"jti"`
    RevokedAt time.Time `json:"revoked_at"`
}
