package models

import "gorm.io/gorm"

type User struct {
	gorm.Model // adds automatically ID, CreatedAt, UpdatedAt, DeletedAt fields
	Email    string `gorm:"unique;not null" json:"email"`
	Password string `gorm:"not null" json:"password"` 
}