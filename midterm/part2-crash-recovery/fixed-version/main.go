package main

import (
	"context"
	"runtime"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type Product struct {
	ID          int     `json:"id"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Price       float64 `json:"price"`
}

var (
	products = &sync.Map{}
)

func main() {
	router := gin.Default()

	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "healthy"})
	})

	router.GET("/metrics", func(c *gin.Context) {
		var count int
		products.Range(func(key, value interface{}) bool {
			count++
			return true
		})

		var m runtime.MemStats
		runtime.ReadMemStats(&m)

		c.JSON(200, gin.H{
			"products":       count,
			"goroutines":     runtime.NumGoroutine(),
			"alloc_mb":       m.Alloc / 1024 / 1024,
			"total_alloc_mb": m.TotalAlloc / 1024 / 1024,
		})
	})

	// FIXED: Goroutine does work and EXITS (doesn't run forever)
	router.POST("/products/analyze/:id", func(c *gin.Context) {
		id := c.Param("id")

		// Spawn a goroutine that does work and completes
		go func() {
			// Create context with 5 second timeout
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()

			// Do some analysis work for up to 5 seconds
			ticker := time.NewTicker(500 * time.Millisecond)
			defer ticker.Stop()

			workCount := 0
			for workCount < 10 {
				select {
				case <-ctx.Done():
					// Timeout reached - exit cleanly
					return
				case <-ticker.C:
					// Do some work (simulate processing)
					_ = make([]byte, 100*1024) // 100KB - small allocation
					workCount++
				}
			}
			// Work complete - goroutine exits
		}()

		c.JSON(200, gin.H{"message": "Analysis started", "product_id": id})
	})

	router.POST("/products/:id", func(c *gin.Context) {
		var product Product
		if err := c.BindJSON(&product); err != nil {
			c.JSON(400, gin.H{"error": err.Error()})
			return
		}

		products.Store(product.ID, product)
		c.JSON(201, gin.H{"message": "Product created"})
	})

	router.GET("/products/:id", func(c *gin.Context) {
		id := c.Param("id")

		value, exists := products.Load(id)
		if !exists {
			c.JSON(404, gin.H{"error": "Product not found"})
			return
		}

		c.JSON(200, value)
	})

	router.Run(":8080")
}
