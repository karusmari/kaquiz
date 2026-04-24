package models 

import "time"

type Friendship struct {
	ID        uint      `gorm:"primaryKey"`
	UserID    uint      `gorm:"not null" json:"user_id"`
	FriendID  uint      `gorm:"not null" json:"friend_id"`
	Status	string      `gorm:"default:'pending'" json:"status"` // "pending", "accepted", "rejected"
	CreatedAt time.Time 
}