package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"net/http/cookiejar"
	"sync"
	"sync/atomic"
	"time"
)

// Configuration
var (
	albURL         string
	numClients     int
	numRequests    int
	checkoutTarget int
)

// Metrics
type Metrics struct {
	totalRequests    int64
	successfulCarts  int64
	failedCarts      int64
	successfulAdds   int64
	failedAdds       int64
	successfulChecks int64
	failedChecks     int64
	authorizedCount  int64
	declinedCount    int64

	checkoutLatencies []time.Duration
	addItemLatencies  []time.Duration
	mu                sync.Mutex
}

var metrics = &Metrics{
	checkoutLatencies: make([]time.Duration, 0),
	addItemLatencies:  make([]time.Duration, 0),
}

func main() {
	flag.StringVar(&albURL, "url", "http://localhost:8082", "Load Balancer URL")
	flag.IntVar(&numClients, "clients", 10, "Number of concurrent clients")
	flag.IntVar(&numRequests, "requests", 200000, "Total number of checkout requests")
	flag.Parse()

	checkoutTarget = numRequests

	log.Printf("Starting load test...")
	log.Printf("URL: %s", albURL)
	log.Printf("Concurrent clients: %d", numClients)
	log.Printf("Total checkouts: %d", checkoutTarget)

	startTime := time.Now()

	// Create worker goroutines
	var wg sync.WaitGroup
	requestsPerClient := checkoutTarget / numClients

	for i := 0; i < numClients; i++ {
		wg.Add(1)
		go func(clientID int) {
			defer wg.Done()
			runClient(clientID, requestsPerClient)
		}(i)
	}

	wg.Wait()

	duration := time.Since(startTime)

	// Print results
	printResults(duration)
}

func runClient(clientID int, numCheckouts int) {
	// Create HTTP client with cookie jar for sticky sessions
	jar, _ := cookiejar.New(nil)
	client := &http.Client{
		Jar:     jar,
		Timeout: 30 * time.Second,
	}

	for i := 0; i < numCheckouts; i++ {
		// Full checkout flow
		if err := performCheckout(client, clientID, i); err != nil {
			log.Printf("Client %d: Checkout %d failed: %v", clientID, i, err)
		}

		if (i+1)%100 == 0 {
			log.Printf("Client %d: Completed %d checkouts", clientID, i+1)
		}
	}
}

func performCheckout(client *http.Client, clientID, requestNum int) error {
	atomic.AddInt64(&metrics.totalRequests, 1)

	// Step 1: Create cart
	cartID, err := createCart(client, fmt.Sprintf("CLIENT-%d-REQ-%d", clientID, requestNum))
	if err != nil {
		atomic.AddInt64(&metrics.failedCarts, 1)
		return fmt.Errorf("create cart: %w", err)
	}
	atomic.AddInt64(&metrics.successfulCarts, 1)

	// Step 2: Add items
	startAdd := time.Now()
	if err := addItem(client, cartID, "PROD-001", 2); err != nil {
		atomic.AddInt64(&metrics.failedAdds, 1)
		return fmt.Errorf("add item 1: %w", err)
	}
	atomic.AddInt64(&metrics.successfulAdds, 1)

	if err := addItem(client, cartID, "PROD-002", 1); err != nil {
		atomic.AddInt64(&metrics.failedAdds, 1)
		return fmt.Errorf("add item 2: %w", err)
	}
	atomic.AddInt64(&metrics.successfulAdds, 1)
	addLatency := time.Since(startAdd)

	metrics.mu.Lock()
	metrics.addItemLatencies = append(metrics.addItemLatencies, addLatency)
	metrics.mu.Unlock()

	// Step 3: Checkout
	startCheckout := time.Now()
	authorized, err := checkout(client, cartID)
	checkoutLatency := time.Since(startCheckout)

	if err != nil {
		atomic.AddInt64(&metrics.failedChecks, 1)
		return fmt.Errorf("checkout: %w", err)
	}

	metrics.mu.Lock()
	metrics.checkoutLatencies = append(metrics.checkoutLatencies, checkoutLatency)
	metrics.mu.Unlock()

	atomic.AddInt64(&metrics.successfulChecks, 1)
	if authorized {
		atomic.AddInt64(&metrics.authorizedCount, 1)
	} else {
		atomic.AddInt64(&metrics.declinedCount, 1)
	}

	return nil
}

func createCart(client *http.Client, customerID string) (string, error) {
	reqBody := map[string]string{"customer_id": customerID}
	jsonData, _ := json.Marshal(reqBody)

	resp, err := client.Post(
		albURL+"/shopping-carts",
		"application/json",
		bytes.NewBuffer(jsonData),
	)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		return "", fmt.Errorf("status %d", resp.StatusCode)
	}

	var result map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&result)
	return result["cart_id"].(string), nil
}

func addItem(client *http.Client, cartID, productID string, quantity int) error {
	reqBody := map[string]interface{}{
		"product_id": productID,
		"quantity":   quantity,
	}
	jsonData, _ := json.Marshal(reqBody)

	resp, err := client.Post(
		fmt.Sprintf("%s/shopping-carts/%s/items", albURL, cartID),
		"application/json",
		bytes.NewBuffer(jsonData),
	)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("status %d", resp.StatusCode)
	}

	return nil
}

func checkout(client *http.Client, cartID string) (bool, error) {
	reqBody := map[string]string{
		"credit_card_number": "1234-5678-9012-3456",
	}
	jsonData, _ := json.Marshal(reqBody)

	resp, err := client.Post(
		fmt.Sprintf("%s/shopping-carts/%s/checkout", albURL, cartID),
		"application/json",
		bytes.NewBuffer(jsonData),
	)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	var result map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&result)

	// 200 = authorized, 402 = declined
	if resp.StatusCode == http.StatusOK {
		return true, nil
	} else if resp.StatusCode == http.StatusPaymentRequired {
		return false, nil // Declined but not an error
	}

	return false, fmt.Errorf("status %d", resp.StatusCode)
}

func printResults(duration time.Duration) {
	fmt.Println("\n========================================")
	fmt.Println("Load Test Results")
	fmt.Println("========================================")
	fmt.Printf("Total Duration: %v\n", duration)
	fmt.Printf("Total Requests: %d\n", metrics.totalRequests)
	fmt.Printf("\nCart Operations:\n")
	fmt.Printf("  Created: %d\n", metrics.successfulCarts)
	fmt.Printf("  Failed: %d\n", metrics.failedCarts)
	fmt.Printf("\nItem Operations:\n")
	fmt.Printf("  Successful: %d\n", metrics.successfulAdds)
	fmt.Printf("  Failed: %d\n", metrics.failedAdds)
	fmt.Printf("\nCheckout Operations:\n")
	fmt.Printf("  Successful: %d\n", metrics.successfulChecks)
	fmt.Printf("  Failed: %d\n", metrics.failedChecks)
	fmt.Printf("  Authorized: %d (%.1f%%)\n", metrics.authorizedCount,
		float64(metrics.authorizedCount)/float64(metrics.successfulChecks)*100)
	fmt.Printf("  Declined: %d (%.1f%%)\n", metrics.declinedCount,
		float64(metrics.declinedCount)/float64(metrics.successfulChecks)*100)

	fmt.Printf("\nThroughput:\n")
	throughput := float64(metrics.successfulChecks) / duration.Seconds()
	fmt.Printf("  Checkouts/sec: %.2f\n", throughput)

	// Calculate latency percentiles
	if len(metrics.checkoutLatencies) > 0 {
		fmt.Printf("\nCheckout Latencies:\n")
		printLatencyStats(metrics.checkoutLatencies)
	}

	if len(metrics.addItemLatencies) > 0 {
		fmt.Printf("\nAdd Items Latencies:\n")
		printLatencyStats(metrics.addItemLatencies)
	}

	fmt.Println("========================================")
}

func printLatencyStats(latencies []time.Duration) {
	// Calculate percentiles
	sorted := make([]time.Duration, len(latencies))
	copy(sorted, latencies)

	// Simple bubble sort for small datasets
	for i := 0; i < len(sorted); i++ {
		for j := i + 1; j < len(sorted); j++ {
			if sorted[i] > sorted[j] {
				sorted[i], sorted[j] = sorted[j], sorted[i]
			}
		}
	}

	p50 := sorted[len(sorted)*50/100]
	p95 := sorted[len(sorted)*95/100]
	p99 := sorted[len(sorted)*99/100]
	max := sorted[len(sorted)-1]

	avg := time.Duration(0)
	for _, l := range sorted {
		avg += l
	}
	avg = avg / time.Duration(len(sorted))

	fmt.Printf("  Average: %v\n", avg)
	fmt.Printf("  P50: %v\n", p50)
	fmt.Printf("  P95: %v\n", p95)
	fmt.Printf("  P99: %v\n", p99)
	fmt.Printf("  Max: %v\n", max)
}
