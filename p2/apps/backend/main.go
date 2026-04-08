package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

type Vote struct {
	AppID  string `json:"app_id" binding:"required"`
	Choice string `json:"choice" binding:"required"`
}

var db *sql.DB

func initDB() {
	var err error
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		os.Getenv("DB_HOST"), os.Getenv("DB_PORT"), os.Getenv("DB_USER"), os.Getenv("DB_PASSWORD"), os.Getenv("DB_NAME"))

	// DBの起動を待つためのリトライ処理
	for i := 0; i < 10; i++ {
		db, err = sql.Open("postgres", connStr)
		if err == nil {
			err = db.Ping()
			if err == nil {
				break
			}
		}
		log.Printf("Failed to connect to DB, retrying... (%d/10)", i+1)
		time.Sleep(2 * time.Second)
	}

	if err != nil {
		log.Fatal("Could not connect to DB:", err)
	}

	// テーブルの作成（存在しない場合）
	query := `
	CREATE TABLE IF NOT EXISTS votes (
		id SERIAL PRIMARY KEY,
		app_id TEXT NOT NULL,
		choice TEXT NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);`
	_, err = db.Exec(query)
	if err != nil {
		log.Fatal("Could not create table:", err)
	}
}

func main() {
	initDB()

	r := gin.Default()
	r.Use(cors.Default())

	api := r.Group("/api")
	{
		// Health check
		api.GET("/health", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{"status": "ok"})
		})

		// 投票
		api.POST("/vote", func(c *gin.Context) {
			var vote Vote
			if err := c.ShouldBindJSON(&vote); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			_, err := db.Exec("INSERT INTO votes (app_id, choice) VALUES ($1, $2)", vote.AppID, vote.Choice)
			if err != nil {
				log.Printf("Error inserting vote: %v", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save vote"})
				return
			}

			c.JSON(http.StatusOK, gin.H{"status": "voted"})
		})

		// 集計結果
		api.GET("/results/:app_id", func(c *gin.Context) {
			appID := c.Param("app_id")
			rows, err := db.Query("SELECT choice, count(*) FROM votes WHERE app_id = $1 GROUP BY choice", appID)
			if err != nil {
				log.Printf("Error fetching results: %v", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch results"})
				return
			}
			defer rows.Close()

			results := make(map[string]int)
			for rows.Next() {
				var choice string
				var count int
				if err := rows.Scan(&choice, &count); err != nil {
					continue
				}
				results[choice] = count
			}
			c.JSON(http.StatusOK, results)
		})
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	r.Run(":" + port)
}
