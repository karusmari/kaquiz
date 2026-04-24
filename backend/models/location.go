package models 

import "time"

type Location struct {
	UserID    uint      `gorm:"primaryKey" json:"user_id"`
	Latitude  float64   `json:"latitude"`
	Longitude float64   `json:"longitude"`
	UpdatedAt time.Time `json:"updated_at"`
}