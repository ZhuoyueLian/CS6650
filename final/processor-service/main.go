package main

import (
	"context"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
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
	processedCounter uint64
	failedCounter    uint64
	retriedCounter   uint64
)

var (
	sqsClient   *sqs.Client
	snsClient   *sns.Client
	sqsQueueURL string
	snsTopicARN string
	failureRate float64
)

func main() {
	initAWS()

	// Start health check server in background
	go startHealthServer()

	// Start processing workers
	numWorkers := getEnvInt("NUM_WORKERS", 1)
	fmt.Printf("Starting %d processor workers\n", numWorkers)

	for i := 0; i < numWorkers; i++ {
		go worker(i + 1)
	}

	// Keep main alive
	select {}
}

func initAWS() {
	sqsQueueURL = os.Getenv("SQS_QUEUE_URL")
	snsTopicARN = os.Getenv("SNS_TOPIC_ARN")
	region := os.Getenv("AWS_REGION")
	endpoint := os.Getenv("AWS_ENDPOINT_URL")

	// Parse failure rate
	if fr := os.Getenv("FAILURE_RATE"); fr != "" {
		if rate, err := strconv.ParseFloat(fr, 64); err == nil {
			failureRate = rate
			fmt.Printf("Failure injection enabled: %.0f%%\n", failureRate*100)
		}
	}

	if region == "" {
		region = "us-east-1"
	}

	opts := []func(*config.LoadOptions) error{
		config.WithRegion(region),
	}

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
		os.Exit(1)
	}

	sqsClient = sqs.NewFromConfig(cfg)
	snsClient = sns.NewFromConfig(cfg)

	fmt.Printf("Processor initialized - Region: %s, Endpoint: %s\n", region, endpoint)
	fmt.Printf("SQS Queue: %s\n", sqsQueueURL)
	fmt.Printf("SNS Topic: %s\n", snsTopicARN)
}

func startHealthServer() {
	router := gin.Default()
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "healthy"})
	})
	router.GET("/metrics", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"processed": atomic.LoadUint64(&processedCounter),
			"failed":    atomic.LoadUint64(&failedCounter),
			"retried":   atomic.LoadUint64(&retriedCounter),
		})
	})
	router.Run(":8081")
}

func worker(id int) {
	fmt.Printf("Worker %d started\n", id)

	for {
		result, err := sqsClient.ReceiveMessage(context.TODO(), &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(sqsQueueURL),
			MaxNumberOfMessages: 10,
			WaitTimeSeconds:     20,
			AttributeNames:      []types.QueueAttributeName{"ApproximateReceiveCount"},
		})

		if err != nil {
			fmt.Printf("Worker %d: Error receiving messages: %v\n", id, err)
			time.Sleep(5 * time.Second)
			continue
		}

		for _, message := range result.Messages {
			processMessage(id, message)
		}
	}
}

func processMessage(workerID int, message types.Message) {
	var order Order
	if err := json.Unmarshal([]byte(*message.Body), &order); err != nil {
		fmt.Printf("Worker %d: Failed to parse order: %v\n", workerID, err)
		deleteMessage(message.ReceiptHandle)
		return
	}

	// Check receive count for retry tracking
	receiveCount := 1
	if count, ok := message.Attributes["ApproximateReceiveCount"]; ok {
		if c, err := strconv.Atoi(count); err == nil {
			receiveCount = c
		}
	}

	if receiveCount > 1 {
		atomic.AddUint64(&retriedCounter, 1)
		fmt.Printf("Worker %d: RETRY #%d for order %s\n", workerID, receiveCount-1, order.OrderID)
	}

	fmt.Printf("Worker %d: Processing order %s (attempt %d)\n", workerID, order.OrderID, receiveCount)

	// FAILURE INJECTION
	if failureRate > 0 && rand.Float64() < failureRate {
		atomic.AddUint64(&failedCounter, 1)
		fmt.Printf("Worker %d: ❌ SIMULATED FAILURE for order %s (will retry)\n", workerID, order.OrderID)
		// Don't delete message - let it become visible again for retry
		return
	}

	// Simulate processing time
	time.Sleep(100 * time.Millisecond)

	// Mark as completed and publish to SNS
	order.Status = "completed"
	orderJSON, _ := json.Marshal(order)

	_, err := snsClient.Publish(context.TODO(), &sns.PublishInput{
		TopicArn: aws.String(snsTopicARN),
		Message:  aws.String(string(orderJSON)),
	})

	if err != nil {
		fmt.Printf("Worker %d: Failed to publish to SNS: %v\n", workerID, err)
		return
	}

	atomic.AddUint64(&processedCounter, 1)
	fmt.Printf("Worker %d: ✓ Completed order %s\n", workerID, order.OrderID)

	// Delete message from queue
	deleteMessage(message.ReceiptHandle)
}

func deleteMessage(receiptHandle *string) {
	_, err := sqsClient.DeleteMessage(context.TODO(), &sqs.DeleteMessageInput{
		QueueUrl:      aws.String(sqsQueueURL),
		ReceiptHandle: receiptHandle,
	})
	if err != nil {
		fmt.Printf("Failed to delete message: %v\n", err)
	}
}

func getEnvInt(key string, defaultVal int) int {
	if val := os.Getenv(key); val != "" {
		if i, err := strconv.Atoi(val); err == nil {
			return i
		}
	}
	return defaultVal
}
