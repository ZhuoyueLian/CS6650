package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"sync/atomic"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/gin-gonic/gin"
)

type Order struct {
	OrderID    string    `json:"order_id"`
	CustomerID int       `json:"customer_id"`
	Status     string    `json:"status"`
	Items      []Item    `json:"items"`
	CreatedAt  time.Time `json:"created_at"`
}

type Item struct {
	ProductID int     `json:"product_id"`
	Quantity  int     `json:"quantity"`
	Price     float64 `json:"price"`
}

var (
	orderCounter   uint64
	successCounter uint64
	failureCounter uint64
)

var sqsClient *sqs.Client
var sqsQueueURL string

func main() {
	initAWS()

	router := gin.Default()
	router.GET("/health", healthCheck)
	router.POST("/orders", createOrder)
	router.GET("/metrics", getMetrics)

	fmt.Println("Order Service starting on :8080")
	router.Run(":8080")
}

func initAWS() {
	sqsQueueURL = os.Getenv("SQS_QUEUE_URL")
	region := os.Getenv("AWS_REGION")
	endpoint := os.Getenv("AWS_ENDPOINT_URL") // For LocalStack

	if region == "" {
		region = "us-east-1"
	}

	opts := []func(*config.LoadOptions) error{
		config.WithRegion(region),
	}

	// Add custom endpoint if specified (for LocalStack)
	if endpoint != "" {
		customResolver := aws.EndpointResolverWithOptionsFunc(
			func(service, region string, options ...interface{}) (aws.Endpoint, error) {
				return aws.Endpoint{
					URL:           endpoint,
					SigningRegion: region,
				}, nil
			})
		opts = append(opts, config.WithEndpointResolverWithOptions(customResolver))
	}

	cfg, err := config.LoadDefaultConfig(context.TODO(), opts...)
	if err != nil {
		fmt.Printf("Failed to load AWS config: %v\n", err)
		return
	}

	sqsClient = sqs.NewFromConfig(cfg)

	fmt.Printf("AWS initialized - Region: %s, Endpoint: %s\n", region, endpoint)
	fmt.Printf("SQS Queue: %s\n", sqsQueueURL)
}

func healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "healthy"})
}

func createOrder(c *gin.Context) {
	var order Order

	if err := c.BindJSON(&order); err != nil {
		atomic.AddUint64(&failureCounter, 1)
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	// Generate order ID
	orderNum := atomic.AddUint64(&orderCounter, 1)
	if order.OrderID == "" {
		order.OrderID = fmt.Sprintf("ORD-%d", orderNum)
	}
	order.CreatedAt = time.Now()
	order.Status = "pending"

	// Publish to SQS
	orderJSON, _ := json.Marshal(order)
	_, err := sqsClient.SendMessage(context.TODO(), &sqs.SendMessageInput{
		QueueUrl:    aws.String(sqsQueueURL),
		MessageBody: aws.String(string(orderJSON)),
	})

	if err != nil {
		fmt.Printf("Failed to send to SQS: %v\n", err)
		atomic.AddUint64(&failureCounter, 1)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to queue order"})
		return
	}

	atomic.AddUint64(&successCounter, 1)

	c.JSON(http.StatusAccepted, gin.H{
		"order_id": order.OrderID,
		"status":   order.Status,
		"message":  "Order queued for processing",
	})
}

func getMetrics(c *gin.Context) {
	total := atomic.LoadUint64(&orderCounter)
	success := atomic.LoadUint64(&successCounter)
	failure := atomic.LoadUint64(&failureCounter)

	c.JSON(http.StatusOK, gin.H{
		"total_orders":      total,
		"successful_orders": success,
		"failed_orders":     failure,
	})
}
