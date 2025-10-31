package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	_ "github.com/go-sql-driver/mysql"
)

// Cart represents a shopping cart
type Cart struct {
	CartID     int        `json:"cart_id"`
	CustomerID string     `json:"customer_id"`
	CreatedAt  time.Time  `json:"created_at"`
	Items      []CartItem `json:"items,omitempty"`
}

// CartItem represents an item in a shopping cart
type CartItem struct {
	ItemID    int     `json:"item_id"`
	CartID    int     `json:"cart_id"`
	ProductID string  `json:"product_id"`
	Quantity  int     `json:"quantity"`
	Price     float64 `json:"price"`
}

// CreateCartRequest represents the request body for creating a cart
type CreateCartRequest struct {
	CustomerID string `json:"customer_id" binding:"required"`
}

// AddItemRequest represents the request body for adding items
type AddItemRequest struct {
	ProductID string  `json:"product_id" binding:"required"`
	Quantity  int     `json:"quantity" binding:"required,min=1"`
	Price     float64 `json:"price" binding:"required,min=0"`
}

var db *sql.DB

func main() {
	// Initialize database connection
	var err error
	db, err = initDB()
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()

	// Initialize database schema
	if err := initSchema(); err != nil {
		log.Fatalf("Failed to initialize schema: %v", err)
	}

	router := gin.Default()

	// Health check endpoint
	router.GET("/health", healthCheck)

	// Shopping cart endpoints
	router.POST("/shopping-carts", createCart)
	router.GET("/shopping-carts/:id", getCart)
	router.POST("/shopping-carts/:id/items", addItems)

	router.Run(":8080")
}

// initDB initializes database connection with connection pooling
func initDB() (*sql.DB, error) {
	// Get database credentials from environment variables
	dbHost := os.Getenv("DB_HOST")
	dbPort := os.Getenv("DB_PORT")
	dbUser := os.Getenv("DB_USER")
	dbPassword := os.Getenv("DB_PASSWORD")
	dbName := os.Getenv("DB_NAME")

	// Construct DSN (Data Source Name)
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true",
		dbUser, dbPassword, dbHost, dbPort, dbName)

	// Open database connection
	database, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, fmt.Errorf("error opening database: %w", err)
	}

	// Configure connection pool
	database.SetMaxOpenConns(25)
	database.SetMaxIdleConns(5)
	database.SetConnMaxLifetime(5 * time.Minute)

	// Test connection
	if err := database.Ping(); err != nil {
		return nil, fmt.Errorf("error connecting to database: %w", err)
	}

	log.Println("Successfully connected to MySQL database")
	return database, nil
}

// initSchema creates the database tables if they don't exist
func initSchema() error {
	// Create carts table
	createCartsTable := `
	CREATE TABLE IF NOT EXISTS carts (
		cart_id INT AUTO_INCREMENT PRIMARY KEY,
		customer_id VARCHAR(255) NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		INDEX idx_customer_id (customer_id)
	) ENGINE=InnoDB;`

	if _, err := db.Exec(createCartsTable); err != nil {
		return fmt.Errorf("error creating carts table: %w", err)
	}

	// Create cart_items table
	createCartItemsTable := `
	CREATE TABLE IF NOT EXISTS cart_items (
		item_id INT AUTO_INCREMENT PRIMARY KEY,
		cart_id INT NOT NULL,
		product_id VARCHAR(255) NOT NULL,
		quantity INT NOT NULL,
		price DECIMAL(10, 2) NOT NULL,
		FOREIGN KEY (cart_id) REFERENCES carts(cart_id) ON DELETE CASCADE,
		INDEX idx_cart_id (cart_id)
	) ENGINE=InnoDB;`

	if _, err := db.Exec(createCartItemsTable); err != nil {
		return fmt.Errorf("error creating cart_items table: %w", err)
	}

	log.Println("Database schema initialized successfully")
	return nil
}

// healthCheck endpoint for load balancer
func healthCheck(c *gin.Context) {
	// Check database connection
	if err := db.Ping(); err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status": "unhealthy",
			"error":  "database connection failed",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "healthy"})
}

// createCart creates a new shopping cart
func createCart(c *gin.Context) {
	var req CreateCartRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	// Insert cart into database
	result, err := db.Exec(
		"INSERT INTO carts (customer_id) VALUES (?)",
		req.CustomerID,
	)
	if err != nil {
		log.Printf("Error creating cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create cart"})
		return
	}

	// Get the generated cart ID
	cartID, err := result.LastInsertId()
	if err != nil {
		log.Printf("Error getting cart ID: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to retrieve cart ID"})
		return
	}

	// Fetch the created cart
	cart, err := fetchCartByID(int(cartID))
	if err != nil {
		log.Printf("Error fetching created cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "cart created but failed to retrieve"})
		return
	}

	c.JSON(http.StatusCreated, cart)
}

// getCart retrieves a cart with all its items
func getCart(c *gin.Context) {
	cartID := c.Param("id")

	cart, err := fetchCartByID(parseID(cartID))
	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "cart not found"})
			return
		}
		log.Printf("Error fetching cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to retrieve cart"})
		return
	}

	c.JSON(http.StatusOK, cart)
}

// addItems adds or updates items in a cart
func addItems(c *gin.Context) {
	cartID := parseID(c.Param("id"))

	// Verify cart exists
	exists, err := cartExists(cartID)
	if err != nil {
		log.Printf("Error checking cart existence: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to verify cart"})
		return
	}
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "cart not found"})
		return
	}

	var req AddItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	// Insert or update cart item
	_, err = db.Exec(`
		INSERT INTO cart_items (cart_id, product_id, quantity, price)
		VALUES (?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE
		quantity = quantity + VALUES(quantity)`,
		cartID, req.ProductID, req.Quantity, req.Price,
	)
	if err != nil {
		log.Printf("Error adding item to cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to add item"})
		return
	}

	// Fetch updated cart
	cart, err := fetchCartByID(cartID)
	if err != nil {
		log.Printf("Error fetching updated cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "item added but failed to retrieve cart"})
		return
	}

	c.JSON(http.StatusOK, cart)
}

// Helper functions

func parseID(idStr string) int {
	var id int
	fmt.Sscanf(idStr, "%d", &id)
	return id
}

func cartExists(cartID int) (bool, error) {
	var exists bool
	err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM carts WHERE cart_id = ?)", cartID).Scan(&exists)
	return exists, err
}

func fetchCartByID(cartID int) (*Cart, error) {
	// Fetch cart
	var cart Cart
	err := db.QueryRow(
		"SELECT cart_id, customer_id, created_at FROM carts WHERE cart_id = ?",
		cartID,
	).Scan(&cart.CartID, &cart.CustomerID, &cart.CreatedAt)

	if err != nil {
		return nil, err
	}

	// Fetch cart items
	rows, err := db.Query(`
		SELECT item_id, cart_id, product_id, quantity, price
		FROM cart_items
		WHERE cart_id = ?`,
		cartID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	cart.Items = []CartItem{}
	for rows.Next() {
		var item CartItem
		if err := rows.Scan(&item.ItemID, &item.CartID, &item.ProductID, &item.Quantity, &item.Price); err != nil {
			return nil, err
		}
		cart.Items = append(cart.Items, item)
	}

	return &cart, nil
}
