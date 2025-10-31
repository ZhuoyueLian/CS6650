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

// Cart represents a shopping cart in DynamoDB
type Cart struct {
	CartID     string     `dynamodbav:"cart_id" json:"cart_id"`
	CustomerID string     `dynamodbav:"customer_id" json:"customer_id"`
	CreatedAt  string     `dynamodbav:"created_at" json:"created_at"`
	Items      []CartItem `dynamodbav:"items" json:"items,omitempty"`
}

// CartItem represents an item in the cart
type CartItem struct {
	ProductID string  `dynamodbav:"product_id" json:"product_id"`
	Quantity  int     `dynamodbav:"quantity" json:"quantity"`
	Price     float64 `dynamodbav:"price" json:"price"`
}

// CreateCartRequest for creating carts
type CreateCartRequest struct {
	CustomerID string `json:"customer_id" binding:"required"`
}

// AddItemRequest for adding items
type AddItemRequest struct {
	ProductID string  `json:"product_id" binding:"required"`
	Quantity  int     `json:"quantity" binding:"required,min=1"`
	Price     float64 `json:"price" binding:"required,min=0"`
}

var (
	dynamoClient *dynamodb.Client
	tableName    string
)

func main() {
	// Get table name from environment
	tableName = os.Getenv("DYNAMODB_TABLE")
	if tableName == "" {
		log.Fatal("DYNAMODB_TABLE environment variable not set")
	}

	// Initialize DynamoDB client
	var err error
	dynamoClient, err = initDynamoDB()
	if err != nil {
		log.Fatalf("Failed to initialize DynamoDB: %v", err)
	}

	router := gin.Default()

	// Health check
	router.GET("/health", healthCheck)

	// Shopping cart endpoints
	router.POST("/shopping-carts", createCart)
	router.GET("/shopping-carts/:id", getCart)
	router.POST("/shopping-carts/:id/items", addItems)

	router.Run(":8080")
}

func initDynamoDB() (*dynamodb.Client, error) {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return nil, fmt.Errorf("unable to load SDK config: %w", err)
	}

	client := dynamodb.NewFromConfig(cfg)
	log.Println("Successfully connected to DynamoDB")
	return client, nil
}

func healthCheck(c *gin.Context) {
	// Test DynamoDB connection by listing tables
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := dynamoClient.ListTables(ctx, &dynamodb.ListTablesInput{Limit: aws.Int32(1)})
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status": "unhealthy",
			"error":  "DynamoDB connection failed",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "healthy"})
}

func createCart(c *gin.Context) {
	var req CreateCartRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	// Create cart with UUID
	cart := Cart{
		CartID:     uuid.New().String(),
		CustomerID: req.CustomerID,
		CreatedAt:  time.Now().UTC().Format(time.RFC3339),
		Items:      []CartItem{},
	}

	// Marshal cart to DynamoDB format
	item, err := attributevalue.MarshalMap(cart)
	if err != nil {
		log.Printf("Error marshaling cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create cart"})
		return
	}

	// Put item in DynamoDB
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

	c.JSON(http.StatusCreated, cart)
}

func getCart(c *gin.Context) {
	cartID := c.Param("id")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Get item from DynamoDB
	result, err := dynamoClient.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"cart_id": &types.AttributeValueMemberS{Value: cartID},
		},
	})
	if err != nil {
		log.Printf("Error getting item: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to retrieve cart"})
		return
	}

	if result.Item == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "cart not found"})
		return
	}

	// Unmarshal result
	var cart Cart
	err = attributevalue.UnmarshalMap(result.Item, &cart)
	if err != nil {
		log.Printf("Error unmarshaling cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse cart"})
		return
	}

	c.JSON(http.StatusOK, cart)
}

func addItems(c *gin.Context) {
	cartID := c.Param("id")

	var req AddItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// First, check if cart exists
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

	if getResult.Item == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "cart not found"})
		return
	}

	// Unmarshal existing cart
	var cart Cart
	err = attributevalue.UnmarshalMap(getResult.Item, &cart)
	if err != nil {
		log.Printf("Error unmarshaling cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse cart"})
		return
	}

	// Add new item (or update quantity if product already exists)
	found := false
	for i, item := range cart.Items {
		if item.ProductID == req.ProductID {
			cart.Items[i].Quantity += req.Quantity
			found = true
			break
		}
	}

	if !found {
		cart.Items = append(cart.Items, CartItem{
			ProductID: req.ProductID,
			Quantity:  req.Quantity,
			Price:     req.Price,
		})
	}

	// Marshal updated cart
	item, err := attributevalue.MarshalMap(cart)
	if err != nil {
		log.Printf("Error marshaling updated cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update cart"})
		return
	}

	// Update cart in DynamoDB
	_, err = dynamoClient.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
	})
	if err != nil {
		log.Printf("Error updating cart: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to add item"})
		return
	}

	c.JSON(http.StatusOK, cart)
}
