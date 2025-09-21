package main

import (
	"fmt"
	"sync"
	"sync/atomic"
)

func main() {
	// Atomic counter version
	fmt.Println("=== Atomic Counter Test ===")
	var atomicOps atomic.Uint64
	var wg sync.WaitGroup

	for i := 0; i < 50; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < 1000; j++ {
				atomicOps.Add(1)
			}
		}()
	}

	wg.Wait()
	fmt.Println("Atomic ops:", atomicOps.Load())

	// Regular counter version (for comparison)
	fmt.Println("\n=== Regular Counter Test ===")
	var regularOps uint64
	var wg2 sync.WaitGroup

	for i := 0; i < 50; i++ {
		wg2.Add(1)
		go func() {
			defer wg2.Done()
			for j := 0; j < 1000; j++ {
				regularOps++ // This is NOT thread-safe!
			}
		}()
	}

	wg2.Wait()
	fmt.Println("Regular ops:", regularOps)
	fmt.Println("Expected:", 50*1000)
}
