package main

import (
	"fmt"
	"runtime"
	"time"
)

const (
	iterations = 1000000 // 1 million ping-pong exchanges
)

// Test 1: Single OS thread context switching
func testSingleThreadSwitching() time.Duration {
	// Force Go to use only one OS thread
	runtime.GOMAXPROCS(1)

	// Create unbuffered channel for synchronization
	ch := make(chan struct{})
	done := make(chan struct{})

	start := time.Now()

	// Goroutine 1: Sender
	go func() {
		defer close(done)
		for i := 0; i < iterations; i++ {
			ch <- struct{}{} // Send signal
			<-ch             // Wait for acknowledgment
		}
	}()

	// Goroutine 2: Receiver
	go func() {
		for i := 0; i < iterations; i++ {
			<-ch             // Wait for signal
			ch <- struct{}{} // Send acknowledgment
		}
	}()

	// Wait for completion
	<-done

	elapsed := time.Since(start)
	return elapsed
}

// Test 2: Multi-threaded context switching
func testMultiThreadSwitching() time.Duration {
	// Allow Go to use multiple OS threads
	runtime.GOMAXPROCS(runtime.NumCPU())

	// Create unbuffered channel for synchronization
	ch := make(chan struct{})
	done := make(chan struct{})

	start := time.Now()

	// Goroutine 1: Sender
	go func() {
		defer close(done)
		for i := 0; i < iterations; i++ {
			ch <- struct{}{} // Send signal
			<-ch             // Wait for acknowledgment
		}
	}()

	// Goroutine 2: Receiver
	go func() {
		for i := 0; i < iterations; i++ {
			<-ch             // Wait for signal
			ch <- struct{}{} // Send acknowledgment
		}
	}()

	// Wait for completion
	<-done

	elapsed := time.Since(start)
	return elapsed
}

func calculateSwitchTime(totalTime time.Duration, iterations int) time.Duration {
	// Each iteration involves 2 context switches (ping + pong)
	totalSwitches := iterations * 2
	return totalTime / time.Duration(totalSwitches)
}

func main() {
	fmt.Println("Context Switching Performance Experiment")
	fmt.Println("=======================================")
	fmt.Printf("CPU cores available: %d\n", runtime.NumCPU())
	fmt.Printf("Iterations: %d (= %d total context switches)\n\n", iterations, iterations*2)

	// Run multiple times for statistical reliability
	singleThreadTimes := make([]time.Duration, 0)
	multiThreadTimes := make([]time.Duration, 0)

	fmt.Println("Running experiments (5 runs each)...")
	fmt.Println("------------------------------------")

	for run := 1; run <= 5; run++ {
		fmt.Printf("--- Run %d ---\n", run)

		// Test single-threaded
		fmt.Println("Testing single OS thread switching...")
		singleTime := testSingleThreadSwitching()
		singleThreadTimes = append(singleThreadTimes, singleTime)

		singleSwitchTime := calculateSwitchTime(singleTime, iterations)
		fmt.Printf("Single-thread total time: %v\n", singleTime)
		fmt.Printf("Single-thread avg switch: %v\n", singleSwitchTime)

		// Small delay between tests
		time.Sleep(100 * time.Millisecond)

		// Test multi-threaded
		fmt.Println("Testing multi-thread switching...")
		multiTime := testMultiThreadSwitching()
		multiThreadTimes = append(multiThreadTimes, multiTime)

		multiSwitchTime := calculateSwitchTime(multiTime, iterations)
		fmt.Printf("Multi-thread total time:  %v\n", multiTime)
		fmt.Printf("Multi-thread avg switch:  %v\n", multiSwitchTime)

		// Compare
		if singleTime < multiTime {
			speedup := float64(multiTime.Nanoseconds()) / float64(singleTime.Nanoseconds())
			fmt.Printf("Single-thread is %.2fx faster\n", speedup)
		} else {
			speedup := float64(singleTime.Nanoseconds()) / float64(multiTime.Nanoseconds())
			fmt.Printf("Multi-thread is %.2fx faster\n", speedup)
		}
		fmt.Println()
	}

	// Calculate averages
	var singleSum, multiSum time.Duration
	for i := 0; i < len(singleThreadTimes); i++ {
		singleSum += singleThreadTimes[i]
		multiSum += multiThreadTimes[i]
	}

	singleAvg := singleSum / time.Duration(len(singleThreadTimes))
	multiAvg := multiSum / time.Duration(len(multiThreadTimes))

	singleAvgSwitch := calculateSwitchTime(singleAvg, iterations)
	multiAvgSwitch := calculateSwitchTime(multiAvg, iterations)

	fmt.Println("=== SUMMARY STATISTICS ===")
	fmt.Printf("Single-thread average: %v (avg switch: %v)\n", singleAvg, singleAvgSwitch)
	fmt.Printf("Multi-thread average:  %v (avg switch: %v)\n", multiAvg, multiAvgSwitch)

	if singleAvg < multiAvg {
		speedup := float64(multiAvg.Nanoseconds()) / float64(singleAvg.Nanoseconds())
		improvement := (1 - 1/speedup) * 100
		fmt.Printf("Single-thread is %.2fx faster (%.1f%% improvement)\n", speedup, improvement)
		fmt.Println("Result: Goroutine switching is faster than OS thread switching")
	} else {
		speedup := float64(singleAvg.Nanoseconds()) / float64(multiAvg.Nanoseconds())
		improvement := (1 - 1/speedup) * 100
		fmt.Printf("Multi-thread is %.2fx faster (%.1f%% improvement)\n", speedup, improvement)
		fmt.Println("Result: OS thread parallelism outweighs switching overhead")
	}
}
