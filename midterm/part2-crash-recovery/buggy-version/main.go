package main

import (
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
	products     = &sync.Map{}
	leakedMemory = make([][]byte, 0) // Store leaked memory here
	memoryMutex  = &sync.Mutex{}
)

func main() {
	router := gin.Default()

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "healthy"})
	})

	// Metrics endpoint to see goroutine count and memory
	router.GET("/metrics", func(c *gin.Context) {
		var count int
		products.Range(func(key, value interface{}) bool {
			count++
			return true
		})

		var m runtime.MemStats
		runtime.ReadMemStats(&m)

		memoryMutex.Lock()
		leakedChunks := len(leakedMemory)
		memoryMutex.Unlock()

		c.JSON(200, gin.H{
			"products":       count,
			"goroutines":     runtime.NumGoroutine(),
			"alloc_mb":       m.Alloc / 1024 / 1024,
			"total_alloc_mb": m.TotalAlloc / 1024 / 1024,
			"leaked_chunks":  leakedChunks,
		})
	})

	// BUGGY: This endpoint leaks goroutines AND memory!
	router.POST("/products/analyze/:id", func(c *gin.Context) {
		id := c.Param("id")

		// Spawn a goroutine for "background processing"
		// BUG: This goroutine never exits AND accumulates memory!
		go func() {
			// Leak memory continuously
			for {
				// Allocate 5MB every second and KEEP IT
				chunk := make([]byte, 5*1024*1024) // 5MB

				// Store it so GC can't clean it up
				memoryMutex.Lock()
				leakedMemory = append(leakedMemory, chunk)
				memoryMutex.Unlock()

				time.Sleep(1 * time.Second)
			}
		}()

		c.JSON(200, gin.H{"message": "Analysis started", "product_id": id})
	})

	// Normal endpoint (works fine)
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
