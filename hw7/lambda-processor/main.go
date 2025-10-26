package main

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
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

func handler(ctx context.Context, snsEvent events.SNSEvent) error {
	for _, record := range snsEvent.Records {
		snsRecord := record.SNS

		// Parse the order from SNS message
		var order Order
		if err := json.Unmarshal([]byte(snsRecord.Message), &order); err != nil {
			fmt.Printf("Error parsing order: %v\n", err)
			continue
		}

		fmt.Printf("Processing order: %s\n", order.OrderID)

		// SIMULATE PAYMENT PROCESSING - 3 SECOND DELAY
		time.Sleep(3 * time.Second)

		fmt.Printf("Completed order: %s\n", order.OrderID)
	}

	return nil
}

func main() {
	lambda.Start(handler)
}
