package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Cart represents a shopping cart stored in DynamoDB
type Cart struct {
	CartID     string     `dynamodbav:"cart_id" json:"cart_id"`         // Unique identifier for the cart
	CustomerID string     `dynamodbav:"customer_id" json:"customer_id"` // ID of the customer who owns this cart
	CreatedAt  string     `dynamodbav:"created_at" json:"created_at"`   // Timestamp when cart was created
	Items      []CartItem `dynamodbav:"items" json:"items,omitempty"`   // Array of items in the cart
}

// CartItem represents a single product in a shopping cart
type CartItem struct {
	ProductID string  `dynamodbav:"product_id" json:"product_id"` // Unique identifier for the product
	Quantity  int     `dynamodbav:"quantity" json:"quantity"`     // Number of units of this product
	Price     float64 `dynamodbav:"price" json:"price"`           // Price per unit of the product
}

// Request/Response structs for API endpoints

// CreateCartRequest defines the required data to create a new cart
type CreateCartRequest struct {
	CustomerID string `json:"customer_id" binding:"required"` // Customer ID is required
}

// AddItemRequest defines the data needed to add an item to a cart
type AddItemRequest struct {
	ProductID string  `json:"product_id" binding:"required"`     // Product ID is required
	Quantity  int     `json:"quantity" binding:"required,min=1"` // Quantity must be at least 1
	Price     float64 `json:"price" binding:"required,min=0"`    // Price must be non-negative
}

// UpdateItemRequest defines the data needed to update an item's quantity
type UpdateItemRequest struct {
	Quantity int `json:"quantity" binding:"required,min=1"` // New quantity must be at least 1
}

// Global variables for DynamoDB connection
var (
	dynamoClient *dynamodb.Client // DynamoDB client for database operations
	tableName    string           // Name of the DynamoDB table storing carts
)

// main initializes the application and sets up HTTP routes
func main() {
	// Get DynamoDB table name from environment variable
	// Falls back to default for local development
	tableName = os.Getenv("DYNAMODB_TABLE")
	if tableName == "" {
		tableName = "shopping-carts-local"
		log.Printf("DYNAMODB_TABLE not set, using default: %s", tableName)
	}

	// Initialize connection to DynamoDB
	var err error
	dynamoClient, err = initDynamoDB()
	if err != nil {
		log.Fatalf("Failed to initialize DynamoDB: %v", err)
	}

	// Set up HTTP router with Gin framework
	router := gin.Default()

	// Health check endpoint - used by load balancers to verify service is running
	router.GET("/health", healthCheck)

	// Cart management endpoints
	router.POST("/shopping-carts", createCart)         // Create a new cart
	router.GET("/shopping-carts/:id", getCart)         // Get cart by ID
	router.POST("/shopping-carts/:id/items", addItems) // Add items to cart

	// Item management endpoints - for updating/removing specific items
	router.PUT("/shopping-carts/:cart_id/items/:product_id", updateItem)    // Update item quantity
	router.DELETE("/shopping-carts/:cart_id/items/:product_id", removeItem) // Remove specific item
	router.DELETE("/shopping-carts/:cart_id/items", clearCart)              // Remove all items from cart

	// Start HTTP server on port 8080
	router.Run(":8080")
}

// initDynamoDB creates and configures a DynamoDB client
// Supports both AWS cloud and local DynamoDB instances
func initDynamoDB() (*dynamodb.Client, error) {
	// Load AWS SDK configuration (credentials, region, etc.)
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return nil, fmt.Errorf("unable to load SDK config: %w", err)
	}

	// Check if we should use local DynamoDB (for development/testing)
	endpointURL := os.Getenv("AWS_ENDPOINT_URL_DYNAMODB")

	var client *dynamodb.Client
	if endpointURL != "" {
		// Use local DynamoDB instance (e.g., DynamoDB Local)
		log.Printf("Using local DynamoDB endpoint: %s", endpointURL)
		client = dynamodb.NewFromConfig(cfg, func(o *dynamodb.Options) {
			o.BaseEndpoint = aws.String(endpointURL)
		})
	} else {
		// Use AWS cloud DynamoDB service
		client = dynamodb.NewFromConfig(cfg)
	}

	log.Println("Successfully connected to DynamoDB")
	return client, nil
}

// healthCheck endpoint verifies the service and DynamoDB connection are working
// Returns HTTP 200 if healthy, 503 if DynamoDB is unreachable
func healthCheck(c *gin.Context) {
	// Test DynamoDB connection by attempting to list tables
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Try to list tables (limits to 1 for efficiency)
	_, err := dynamoClient.ListTables(ctx, &dynamodb.ListTablesInput{Limit: aws.Int32(1)})
	if err != nil {
		// DynamoDB is unreachable - service is unhealthy
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status": "unhealthy",
			"error":  "DynamoDB connection failed",
		})
		return
	}

	// Everything is working
	c.JSON(http.StatusOK, gin.H{"status": "healthy"})
}

// createCart creates a new shopping cart for a customer
// POST /shopping-carts
func createCart(c *gin.Context) {
	// Parse and validate the request body
	var req CreateCartRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	// Create a new cart with generated UUID and current timestamp
	cart := Cart{
		CartID:     uuid.New().String(),                   // Generate unique cart ID
		CustomerID: req.CustomerID,                        // Use customer ID from request
		CreatedAt:  time.Now().UTC().Format(time.RFC3339), // Current timestamp in ISO format
		Items:      []CartItem{},                          // Start with empty items array
	}

	// Convert Go struct to DynamoDB attribute format
	item, err := attributevalue.MarshalMap(cart)
	if err != nil {
		log.Printf("Error marshaling cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create cart"})
		return
	}

	// Save the cart to DynamoDB
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err = dynamoClient.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
	})
	if err != nil {
		log.Printf("Error putting item: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create cart"})
		return
	}

	// Return the created cart with HTTP 201 Created status
	c.JSON(http.StatusCreated, cart)
}

// getCart retrieves a cart by its ID, including all items
// GET /shopping-carts/:id
func getCart(c *gin.Context) {
	// Extract cart ID from URL parameter
	cartID := c.Param("id")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Query DynamoDB for the cart using its primary key (cart_id)
	result, err := dynamoClient.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"cart_id": &types.AttributeValueMemberS{Value: cartID}, // Primary key lookup
		},
	})
	if err != nil {
		log.Printf("Error getting item: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to retrieve cart"})
		return
	}

	// Check if cart was found
	if result.Item == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "cart not found"})
		return
	}

	// Convert DynamoDB attributes back to Go struct
	var cart Cart
	err = attributevalue.UnmarshalMap(result.Item, &cart)
	if err != nil {
		log.Printf("Error unmarshaling cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse cart"})
		return
	}

	// Return the cart data
	c.JSON(http.StatusOK, cart)
}

// addItems adds a new item to a cart or increases quantity if item already exists
// POST /shopping-carts/:id/items
func addItems(c *gin.Context) {
	// Extract cart ID from URL
	cartID := c.Param("id")

	// Parse and validate request body
	var req AddItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// First, retrieve the existing cart to verify it exists
	getResult, err := dynamoClient.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"cart_id": &types.AttributeValueMemberS{Value: cartID},
		},
	})
	if err != nil {
		log.Printf("Error getting cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to verify cart"})
		return
	}

	// Verify cart exists
	if getResult.Item == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "cart not found"})
		return
	}

	// Convert DynamoDB data to Go struct
	var cart Cart
	err = attributevalue.UnmarshalMap(getResult.Item, &cart)
	if err != nil {
		log.Printf("Error unmarshaling cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse cart"})
		return
	}

	// Look for existing item with same product ID
	found := false
	for i, item := range cart.Items {
		if item.ProductID == req.ProductID {
			// Item already exists - add to existing quantity
			cart.Items[i].Quantity += req.Quantity
			found = true
			break
		}
	}

	// If item doesn't exist, add as new item
	if !found {
		cart.Items = append(cart.Items, CartItem{
			ProductID: req.ProductID,
			Quantity:  req.Quantity,
			Price:     req.Price,
		})
	}

	// Convert updated cart back to DynamoDB format
	item, err := attributevalue.MarshalMap(cart)
	if err != nil {
		log.Printf("Error marshaling updated cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update cart"})
		return
	}

	// Save updated cart to DynamoDB
	_, err = dynamoClient.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
	})
	if err != nil {
		log.Printf("Error updating cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to add item"})
		return
	}

	// Return updated cart
	c.JSON(http.StatusOK, cart)
}

// updateItem updates the quantity of a specific item in a cart
// PUT /shopping-carts/:cart_id/items/:product_id
func updateItem(c *gin.Context) {
	// Extract cart ID and product ID from URL parameters
	cartID := c.Param("cart_id")
	productID := c.Param("product_id")

	// Parse request body for new quantity
	var req UpdateItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Retrieve the cart from DynamoDB
	getResult, err := dynamoClient.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"cart_id": &types.AttributeValueMemberS{Value: cartID},
		},
	})
	if err != nil {
		log.Printf("Error getting cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to retrieve cart"})
		return
	}

	// Check if cart exists
	if getResult.Item == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "cart not found"})
		return
	}

	// Convert to Go struct
	var cart Cart
	err = attributevalue.UnmarshalMap(getResult.Item, &cart)
	if err != nil {
		log.Printf("Error unmarshaling cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse cart"})
		return
	}

	// Find the specific item and update its quantity
	found := false
	for i, item := range cart.Items {
		if item.ProductID == productID {
			cart.Items[i].Quantity = req.Quantity // Set new quantity
			found = true
			break
		}
	}

	// Return error if item not found in cart
	if !found {
		c.JSON(http.StatusNotFound, gin.H{"error": "item not found in cart"})
		return
	}

	// Convert updated cart to DynamoDB format and save
	item, err := attributevalue.MarshalMap(cart)
	if err != nil {
		log.Printf("Error marshaling cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update cart"})
		return
	}

	_, err = dynamoClient.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
	})
	if err != nil {
		log.Printf("Error saving cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save cart"})
		return
	}

	// Return updated cart
	c.JSON(http.StatusOK, cart)
}

// removeItem removes a specific item completely from a cart
// DELETE /shopping-carts/:cart_id/items/:product_id
func removeItem(c *gin.Context) {
	// Extract cart and product IDs from URL
	cartID := c.Param("cart_id")
	productID := c.Param("product_id")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Get the cart from DynamoDB
	getResult, err := dynamoClient.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"cart_id": &types.AttributeValueMemberS{Value: cartID},
		},
	})
	if err != nil {
		log.Printf("Error getting cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to retrieve cart"})
		return
	}

	// Verify cart exists
	if getResult.Item == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "cart not found"})
		return
	}

	// Convert to Go struct
	var cart Cart
	err = attributevalue.UnmarshalMap(getResult.Item, &cart)
	if err != nil {
		log.Printf("Error unmarshaling cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse cart"})
		return
	}

	// Filter out the item to be removed
	found := false
	newItems := []CartItem{}
	for _, item := range cart.Items {
		if item.ProductID != productID {
			// Keep items that don't match the product ID
			newItems = append(newItems, item)
		} else {
			// Mark that we found the item to remove
			found = true
		}
	}

	// Return error if item wasn't found
	if !found {
		c.JSON(http.StatusNotFound, gin.H{"error": "item not found in cart"})
		return
	}

	// Update cart with filtered items list
	cart.Items = newItems

	// Save updated cart to DynamoDB
	item, err := attributevalue.MarshalMap(cart)
	if err != nil {
		log.Printf("Error marshaling cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update cart"})
		return
	}

	_, err = dynamoClient.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
	})
	if err != nil {
		log.Printf("Error saving cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save cart"})
		return
	}

	// Return updated cart
	c.JSON(http.StatusOK, cart)
}

// clearCart removes all items from a cart (empties the cart)
// DELETE /shopping-carts/:cart_id/items
func clearCart(c *gin.Context) {
	// Extract cart ID from URL
	cartID := c.Param("cart_id")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Get cart to verify it exists
	getResult, err := dynamoClient.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"cart_id": &types.AttributeValueMemberS{Value: cartID},
		},
	})
	if err != nil {
		log.Printf("Error getting cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to retrieve cart"})
		return
	}

	// Check if cart exists
	if getResult.Item == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "cart not found"})
		return
	}

	// Convert to Go struct
	var cart Cart
	err = attributevalue.UnmarshalMap(getResult.Item, &cart)
	if err != nil {
		log.Printf("Error unmarshaling cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse cart"})
		return
	}

	// Clear all items by setting to empty slice
	cart.Items = []CartItem{}

	// Save updated (empty) cart to DynamoDB
	item, err := attributevalue.MarshalMap(cart)
	if err != nil {
		log.Printf("Error marshaling cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update cart"})
		return
	}

	_, err = dynamoClient.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
	})
	if err != nil {
		log.Printf("Error saving cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save cart"})
		return
	}

	// Return the now-empty cart
	c.JSON(http.StatusOK, cart)
}
