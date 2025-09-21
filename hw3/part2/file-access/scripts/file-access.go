package main

import (
	"bufio"
	"fmt"
	"os"
	"time"
)

const (
	iterations = 100000
	filename   = "test_output.txt"
	dataLine   = "This is test data line for file I/O performance testing\n"
)

// Test 1: Unbuffered file writing
func testUnbufferedWrite() (time.Duration, error) {
	// Open or create the output file
	file, err := os.Create(filename + "_unbuffered")
	if err != nil {
		return 0, err
	}
	defer file.Close()
	defer os.Remove(filename + "_unbuffered") // Clean up after test

	start := time.Now()

	// Loop and write directly to file each time
	for i := 0; i < iterations; i++ {
		line := fmt.Sprintf("Line %d: %s", i, dataLine)
		_, err := file.Write([]byte(line))
		if err != nil {
			return 0, err
		}
	}

	elapsed := time.Since(start)
	return elapsed, nil
}

// Test 2: Buffered file writing
func testBufferedWrite() (time.Duration, error) {
	// Open or create the output file
	file, err := os.Create(filename + "_buffered")
	if err != nil {
		return 0, err
	}
	defer file.Close()
	defer os.Remove(filename + "_buffered") // Clean up after test

	// Wrap file in bufio.Writer
	writer := bufio.NewWriter(file)

	start := time.Now()

	// Loop and write to buffer
	for i := 0; i < iterations; i++ {
		line := fmt.Sprintf("Line %d: %s", i, dataLine)
		_, err := writer.WriteString(line)
		if err != nil {
			return 0, err
		}
	}

	// Flush buffer to ensure all data is written
	err = writer.Flush()
	if err != nil {
		return 0, err
	}

	elapsed := time.Since(start)
	return elapsed, nil
}

func runFileAccessExperiment() {
	fmt.Println("=== File Access Performance Experiment ===")
	fmt.Printf("Writing %d lines to files...\n\n", iterations)

	// Test unbuffered writing
	fmt.Println("Testing Unbuffered File Writing:")
	unbufferedTime, err := testUnbufferedWrite()
	if err != nil {
		fmt.Printf("Error in unbuffered test: %v\n", err)
		return
	}
	fmt.Printf("Unbuffered write time: %v\n\n", unbufferedTime)

	// Test buffered writing
	fmt.Println("Testing Buffered File Writing:")
	bufferedTime, err := testBufferedWrite()
	if err != nil {
		fmt.Printf("Error in buffered test: %v\n", err)
		return
	}
	fmt.Printf("Buffered write time: %v\n\n", bufferedTime)

	// Analysis
	fmt.Println("=== Performance Analysis ===")
	fmt.Printf("Unbuffered: %v\n", unbufferedTime)
	fmt.Printf("Buffered:   %v\n", bufferedTime)

	speedup := float64(unbufferedTime.Nanoseconds()) / float64(bufferedTime.Nanoseconds())
	fmt.Printf("Speedup: %.2fx (buffered is %.2fx faster)\n", speedup, speedup)

	if bufferedTime < unbufferedTime {
		improvement := float64(unbufferedTime-bufferedTime) / float64(unbufferedTime) * 100
		fmt.Printf("Performance improvement: %.1f%%\n", improvement)
	}
}

func main() {
	// Run the experiment multiple times to get reliable data
	fmt.Println("File Access Experiment - Multiple Runs")
	fmt.Println("=====================================\n")

	unbufferedTimes := make([]time.Duration, 0)
	bufferedTimes := make([]time.Duration, 0)

	// Run 5 times for statistical reliability
	for run := 1; run <= 5; run++ {
		fmt.Printf("--- Run %d ---\n", run)

		// Test unbuffered
		unbufferedTime, err := testUnbufferedWrite()
		if err != nil {
			fmt.Printf("Error in unbuffered test: %v\n", err)
			continue
		}
		unbufferedTimes = append(unbufferedTimes, unbufferedTime)

		// Test buffered
		bufferedTime, err := testBufferedWrite()
		if err != nil {
			fmt.Printf("Error in buffered test: %v\n", err)
			continue
		}
		bufferedTimes = append(bufferedTimes, bufferedTime)

		fmt.Printf("Unbuffered: %v\n", unbufferedTime)
		fmt.Printf("Buffered:   %v\n", bufferedTime)
		speedup := float64(unbufferedTime.Nanoseconds()) / float64(bufferedTime.Nanoseconds())
		fmt.Printf("Speedup:    %.2fx\n\n", speedup)
	}

	// Calculate averages
	if len(unbufferedTimes) > 0 && len(bufferedTimes) > 0 {
		var unbufferedSum, bufferedSum time.Duration
		for i := 0; i < len(unbufferedTimes); i++ {
			unbufferedSum += unbufferedTimes[i]
			bufferedSum += bufferedTimes[i]
		}

		unbufferedAvg := unbufferedSum / time.Duration(len(unbufferedTimes))
		bufferedAvg := bufferedSum / time.Duration(len(bufferedTimes))

		fmt.Println("=== SUMMARY STATISTICS ===")
		fmt.Printf("Average Unbuffered: %v\n", unbufferedAvg)
		fmt.Printf("Average Buffered:   %v\n", bufferedAvg)

		avgSpeedup := float64(unbufferedAvg.Nanoseconds()) / float64(bufferedAvg.Nanoseconds())
		fmt.Printf("Average Speedup:    %.2fx\n", avgSpeedup)

		improvement := float64(unbufferedAvg-bufferedAvg) / float64(unbufferedAvg) * 100
		fmt.Printf("Performance improvement: %.1f%%\n", improvement)
	}
}
