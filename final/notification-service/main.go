package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"sync/atomic"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"github.com/gin-gonic/gin"
)

type Order struct {
	OrderID    string `json:"order_id"`
	CustomerID int    `json:"customer_id"`
	Status     string `json:"status"`
}

var (
	notificationCounter uint64
	sqsClient           *sqs.Client
	sqsQueueURL         string
)

func main() {
	initAWS()

	go startHealthServer()

	fmt.Println("Notification Service started")
	go worker()

	select {}
}

func initAWS() {
	sqsQueueURL = os.Getenv("SQS_QUEUE_URL")
	region := os.Getenv("AWS_REGION")
	endpoint := os.Getenv("AWS_ENDPOINT_URL")

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
	fmt.Printf("Notification Service initialized - Queue: %s\n", sqsQueueURL)
}

func startHealthServer() {
	router := gin.Default()
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "healthy"})
	})
	router.GET("/metrics", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"notifications_sent": atomic.LoadUint64(&notificationCounter),
		})
	})
	router.Run(":8082")
}

func worker() {
	for {
		result, err := sqsClient.ReceiveMessage(context.TODO(), &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(sqsQueueURL),
			MaxNumberOfMessages: 10,
			WaitTimeSeconds:     20,
		})

		if err != nil {
			fmt.Printf("Error receiving messages: %v\n", err)
			time.Sleep(5 * time.Second)
			continue
		}

		for _, message := range result.Messages {
			processNotification(message)
		}
	}
}

func processNotification(message types.Message) {
	// Parse SNS wrapper
	var snsMessage struct {
		Message string `json:"Message"`
	}

	if err := json.Unmarshal([]byte(*message.Body), &snsMessage); err != nil {
		fmt.Printf("Failed to parse SNS wrapper: %v\n", err)
		deleteMessage(message.ReceiptHandle)
		return
	}

	// Parse order
	var order Order
	if err := json.Unmarshal([]byte(snsMessage.Message), &order); err != nil {
		fmt.Printf("Failed to parse order: %v\n", err)
		deleteMessage(message.ReceiptHandle)
		return
	}

	atomic.AddUint64(&notificationCounter, 1)
	fmt.Printf("📧 NOTIFICATION: Order %s completed for customer %d\n",
		order.OrderID, order.CustomerID)

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
