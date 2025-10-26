package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"github.com/gin-gonic/gin"
)

// Order represents an order in the system
type Order struct {
	OrderID    string    `json:"order_id"`
	CustomerID int       `json:"customer_id"`
	Status     string    `json:"status"` // pending, processing, completed
	Items      []Item    `json:"items"`
	CreatedAt  time.Time `json:"created_at"`
}

// Item represents a product in an order
type Item struct {
	ProductID int     `json:"product_id"`
	Quantity  int     `json:"quantity"`
	Price     float64 `json:"price"`
}

// Counters for metrics
var (
	orderCounter   uint64
	successCounter uint64
	failureCounter uint64
	asyncCounter   uint64
)

// In-memory order storage
var orders sync.Map

// Mutex to simulate single-threaded payment processor
var paymentMutex sync.Mutex

// AWS clients
var (
	snsClient   *sns.Client
	sqsClient   *sqs.Client
	snsTopicARN string
	sqsQueueURL string
)

func main() {
	// Initialize AWS SDK
	initAWS()

	// Get number of workers from environment variable (default: 1)
	numWorkers := 1
	if workersEnv := os.Getenv("NUM_WORKERS"); workersEnv != "" {
		if n, err := strconv.Atoi(workersEnv); err == nil && n > 0 {
			numWorkers = n
		}
	}

	// Start background workers if SQS is configured
	if sqsQueueURL != "" {
		go startWorker(numWorkers)
	}

	router := gin.Default()

	// Health check endpoint
	router.GET("/health", healthCheck)

	// Synchronous order endpoint (Phase 1)
	router.POST("/orders/sync", createOrderSync)

	// Asynchronous order endpoint (Phase 3)
	router.POST("/orders/async", createOrderAsync)

	// Metrics endpoint
	router.GET("/metrics", getMetrics)

	fmt.Println("Order Service starting on :8080")
	router.Run(":8080")
}

func initAWS() {
	snsTopicARN = os.Getenv("SNS_TOPIC_ARN")
	sqsQueueURL = os.Getenv("SQS_QUEUE_URL")
	region := os.Getenv("AWS_REGION")

	if region == "" {
		region = "us-west-2"
	}

	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(region),
	)
	if err != nil {
		fmt.Printf("Failed to load AWS config: %v\n", err)
		return
	}

	snsClient = sns.NewFromConfig(cfg)
	sqsClient = sqs.NewFromConfig(cfg)

	fmt.Printf("AWS initialized - Region: %s\n", region)
	fmt.Printf("SNS Topic: %s\n", snsTopicARN)
	fmt.Printf("SQS Queue: %s\n", sqsQueueURL)
}

// healthCheck returns 200 OK for load balancer
func healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "healthy"})
}

// createOrderSync handles synchronous order processing with 3-second payment delay
func createOrderSync(c *gin.Context) {
	var order Order

	if err := c.BindJSON(&order); err != nil {
		atomic.AddUint64(&failureCounter, 1)
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	// Generate order ID if not provided
	orderNum := atomic.AddUint64(&orderCounter, 1)
	if order.OrderID == "" {
		order.OrderID = fmt.Sprintf("ORD-%d", orderNum)
	}
	order.CreatedAt = time.Now()
	order.Status = "processing"

	// CRITICAL: Lock to simulate single payment processor
	// Only ONE payment can process at a time (the bottleneck!)
	paymentMutex.Lock()
	defer paymentMutex.Unlock()

	// SIMULATE PAYMENT PROCESSING - 3 SECOND DELAY
	time.Sleep(3 * time.Second)

	// After payment, mark as completed
	order.Status = "completed"
	orders.Store(order.OrderID, order)

	atomic.AddUint64(&successCounter, 1)

	c.JSON(http.StatusOK, gin.H{
		"order_id": order.OrderID,
		"status":   order.Status,
		"message":  "Order processed successfully",
	})
}

// createOrderAsync handles asynchronous order processing via SNS
func createOrderAsync(c *gin.Context) {
	var order Order

	if err := c.BindJSON(&order); err != nil {
		atomic.AddUint64(&failureCounter, 1)
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	// Generate order ID
	orderNum := atomic.AddUint64(&orderCounter, 1)
	if order.OrderID == "" {
		order.OrderID = fmt.Sprintf("ORD-ASYNC-%d", orderNum)
	}
	order.CreatedAt = time.Now()
	order.Status = "pending"

	// Store order as pending
	orders.Store(order.OrderID, order)

	// Publish to SNS
	if snsClient != nil && snsTopicARN != "" {
		orderJSON, _ := json.Marshal(order)
		_, err := snsClient.Publish(context.TODO(), &sns.PublishInput{
			TopicArn: aws.String(snsTopicARN),
			Message:  aws.String(string(orderJSON)),
		})

		if err != nil {
			fmt.Printf("Failed to publish to SNS: %v\n", err)
			atomic.AddUint64(&failureCounter, 1)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to queue order"})
			return
		}
	}

	atomic.AddUint64(&asyncCounter, 1)

	// Return immediately with 202 Accepted
	c.JSON(http.StatusAccepted, gin.H{
		"order_id": order.OrderID,
		"status":   order.Status,
		"message":  "Order received and queued for processing",
	})
}

// startWorker polls SQS and processes orders
func startWorker(numWorkers int) {
	fmt.Printf("Starting %d background workers\n", numWorkers)

	for i := 0; i < numWorkers; i++ {
		go worker(i + 1)
	}
}

func worker(id int) {
	fmt.Printf("Worker %d started\n", id)

	for {
		// Poll SQS for messages
		result, err := sqsClient.ReceiveMessage(context.TODO(), &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(sqsQueueURL),
			MaxNumberOfMessages: 10,
			WaitTimeSeconds:     20, // Long polling
		})

		if err != nil {
			fmt.Printf("Worker %d: Error receiving messages: %v\n", id, err)
			time.Sleep(5 * time.Second)
			continue
		}

		// Process each message
		for _, message := range result.Messages {
			processMessage(id, message)
		}
	}
}

func processMessage(workerID int, message types.Message) {
	// Parse SNS message wrapper
	var snsMessage struct {
		Message string `json:"Message"`
	}

	if err := json.Unmarshal([]byte(*message.Body), &snsMessage); err != nil {
		fmt.Printf("Worker %d: Failed to parse SNS wrapper: %v\n", workerID, err)
		return
	}

	// Parse the actual order
	var order Order
	if err := json.Unmarshal([]byte(snsMessage.Message), &order); err != nil {
		fmt.Printf("Worker %d: Failed to parse order: %v\n", workerID, err)
		return
	}

	fmt.Printf("Worker %d: Processing order %s\n", workerID, order.OrderID)

	// Update status to processing
	order.Status = "processing"
	orders.Store(order.OrderID, order)

	// SIMULATE PAYMENT PROCESSING - 3 SECOND DELAY
	time.Sleep(3 * time.Second)

	// Mark as completed
	order.Status = "completed"
	orders.Store(order.OrderID, order)
	atomic.AddUint64(&successCounter, 1)

	fmt.Printf("Worker %d: Completed order %s\n", workerID, order.OrderID)

	// Delete message from queue
	_, err := sqsClient.DeleteMessage(context.TODO(), &sqs.DeleteMessageInput{
		QueueUrl:      aws.String(sqsQueueURL),
		ReceiptHandle: message.ReceiptHandle,
	})

	if err != nil {
		fmt.Printf("Worker %d: Failed to delete message: %v\n", workerID, err)
	}
}

// getMetrics returns current system metrics
func getMetrics(c *gin.Context) {
	total := atomic.LoadUint64(&orderCounter)
	success := atomic.LoadUint64(&successCounter)
	failure := atomic.LoadUint64(&failureCounter)
	async := atomic.LoadUint64(&asyncCounter)

	c.JSON(http.StatusOK, gin.H{
		"total_orders":      total,
		"successful_orders": success,
		"failed_orders":     failure,
		"async_orders":      async,
	})
}
