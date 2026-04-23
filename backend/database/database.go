package database

import (
	"kaquiz-backend/models"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

var DB *gorm.DB

func Connect() {
	db, err := gorm.Open(sqlite.Open("kaquiz.db"), &gorm.Config{})
	if err != nil {
		panic("Connection to database failed")
	}
	db.AutoMigrate(&models.User{})
	DB = db
}