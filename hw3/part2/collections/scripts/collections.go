package main

import (
	"fmt"
	"sync"
	"time"
)

// Test 1: Plain map (unsafe for concurrent access)
// func testPlainMap() {
// 	fmt.Println("=== Test 1: Plain Map (Unsafe) ===")
// 	m := make(map[int]int)
// 	var wg sync.WaitGroup

// 	start := time.Now()

// 	for g := 0; g < 50; g++ {
// 		wg.Add(1)
// 		go func(goroutineID int) {
// 			defer wg.Done()
// 			for i := 0; i < 1000; i++ {
// 				key := goroutineID*1000 + i
// 				m[key] = i // This is NOT thread-safe!
// 			}
// 		}(g)
// 	}

// 	wg.Wait()
// 	elapsed := time.Since(start)

// 	fmt.Printf("Map length: %d (expected: 50000)\n", len(m))
// 	fmt.Printf("Time taken: %v\n", elapsed)
// 	fmt.Println()
// }

// Test 2: Map with Mutex protection
type SafeMapMutex struct {
	mu sync.Mutex
	m  map[int]int
}

func (sm *SafeMapMutex) Set(key, value int) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.m[key] = value
}

func (sm *SafeMapMutex) Len() int {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	return len(sm.m)
}

func testMapWithMutex() {
	fmt.Println("=== Test 2: Map with Mutex ===")
	safeMap := &SafeMapMutex{m: make(map[int]int)}
	var wg sync.WaitGroup

	start := time.Now()

	for g := 0; g < 50; g++ {
		wg.Add(1)
		go func(goroutineID int) {
			defer wg.Done()
			for i := 0; i < 1000; i++ {
				key := goroutineID*1000 + i
				safeMap.Set(key, i)
			}
		}(g)
	}

	wg.Wait()
	elapsed := time.Since(start)

	fmt.Printf("Map length: %d (expected: 50000)\n", safeMap.Len())
	fmt.Printf("Time taken: %v\n", elapsed)
	fmt.Println()
}

// Test 3: Map with RWMutex protection
type SafeMapRWMutex struct {
	mu sync.RWMutex
	m  map[int]int
}

func (sm *SafeMapRWMutex) Set(key, value int) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.m[key] = value
}

func (sm *SafeMapRWMutex) Len() int {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return len(sm.m)
}

func testMapWithRWMutex() {
	fmt.Println("=== Test 3: Map with RWMutex ===")
	safeMap := &SafeMapRWMutex{m: make(map[int]int)}
	var wg sync.WaitGroup

	start := time.Now()

	for g := 0; g < 50; g++ {
		wg.Add(1)
		go func(goroutineID int) {
			defer wg.Done()
			for i := 0; i < 1000; i++ {
				key := goroutineID*1000 + i
				safeMap.Set(key, i)
			}
		}(g)
	}

	wg.Wait()
	elapsed := time.Since(start)

	fmt.Printf("Map length: %d (expected: 50000)\n", safeMap.Len())
	fmt.Printf("Time taken: %v\n", elapsed)
	fmt.Println()
}

// Test 4: sync.Map (built-in concurrent map)
func testSyncMap() {
	fmt.Println("=== Test 4: sync.Map ===")
	var m sync.Map
	var wg sync.WaitGroup

	start := time.Now()

	for g := 0; g < 50; g++ {
		wg.Add(1)
		go func(goroutineID int) {
			defer wg.Done()
			for i := 0; i < 1000; i++ {
				key := goroutineID*1000 + i
				m.Store(key, i)
			}
		}(g)
	}

	wg.Wait()
	elapsed := time.Since(start)

	// Count entries in sync.Map
	count := 0
	m.Range(func(key, value interface{}) bool {
		count++
		return true
	})

	fmt.Printf("Map length: %d (expected: 50000)\n", count)
	fmt.Printf("Time taken: %v\n", elapsed)
	fmt.Println()
}

func main() {
	fmt.Println("Collections Concurrency Experiment")
	fmt.Println("==================================")
	fmt.Println()

	// WARNING: Test 1 might crash your program!
	// fmt.Println("⚠️  WARNING: The first test might crash due to concurrent map writes!")
	// fmt.Println("If it crashes, comment out testPlainMap() and run the other tests.")
	// fmt.Println()

	// Test 1: Plain map (might crash!)
	// testPlainMap()

	// Test 2: Mutex
	testMapWithMutex()

	// Test 3: RWMutex
	testMapWithRWMutex()

	// Test 4: sync.Map
	testSyncMap()
}
