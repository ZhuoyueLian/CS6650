# Part II: Crash and Recovery Experiment - Memory Leak Detection and Remediation in Distributed Systems 

## Executive Summary

This experiment demonstrates a common production failure scenario: goroutine leaks causing memory exhaustion and container crashes. A deliberately buggy Product API endpoint was deployed to AWS ECS with constrained resources (512 MB memory limit). Under load testing, the system exhibited rapid memory growth, goroutine accumulation, and eventual Out-Of-Memory (OOM) kills within 90-120 seconds. The fix implemented proper goroutine lifecycle management using context-based cancellation and timeouts, resulting in stable operation under identical load conditions. This experiment illustrates the critical difference between infrastructure-level health checks and application-level failure handling patterns.

---

## Problem Scenario

### The Buggy Endpoint

A Product API endpoint `/products/analyze/:id` was implemented with a fatal flaw: each request spawned a goroutine that ran an infinite loop, continuously allocating memory without ever terminating.

**Buggy Code:**
```go
router.POST("/products/analyze/:id", func(c *gin.Context) {
    id := c.Param("id")
    
    // BUG: Goroutine never exits!
    go func() {
        for {
            // Allocate 5MB every second and keep it
            chunk := make([]byte, 5*1024*1024)
            leakedMemory = append(leakedMemory, chunk)
            time.Sleep(1 * time.Second)
        }
    }()
    
    c.JSON(200, gin.H{"message": "Analysis started", "product_id": id})
})
```

**Why This Is Dangerous:**
- Each HTTP request creates a permanent goroutine
- Goroutines accumulate memory indefinitely
- No cleanup mechanism
- The endpoint returns 200 OK immediately, hiding the problem
- Health checks still pass until memory exhaustion occurs

---

## Evidence of Failure

### Local Testing Results

**Initial State:**
- Memory: 1 MB
- Goroutines: 3
- Leaked chunks: 0

**After 10 analyze requests:**
- Memory: 4,301 MB (4,300x increase!)
- Goroutines: 13 (10 leaked + 3 baseline)
- Leaked chunks: 860

**Continuous growth over 86 seconds:**
- Memory grew from 1 MB → 96,257 MB
- Leak rate: ~1,100 MB/second
- Leaked chunks: 19,272

*Screenshot: `buggy_local_test_memory_leak_4gb.png`*  
*Screenshot: `buggy_local_test_continuous_memory_growth.png`*

### AWS ECS Deployment Results

**System Configuration:**
- AWS ECS Fargate: 256 CPU units (0.25 vCPU)
- Memory limit: 512 MB
- Auto-scaling: 2-4 instances
- Load testing: Locust with 10 concurrent users

**Observed Behavior Under Load:**

| Time (seconds) | Memory (MB) | Goroutines | Leaked Chunks | Status |
|----------------|-------------|------------|---------------|---------|
| 0 | 431 | 51 | 86 | Running |
| 15 | 1,536 | 95 | 306 | Running |
| 30 | 3,521 | 151 | 704 | Running |
| 45 | 6,101 | 201 | 1,220 | Running |
| 60 | 9,566 | 255 | 1,913 | Running |
| 75 | 14,247 | 313 | 2,848 | Running |
| 90 | 19,491 | 366 | 3,898 | Running |
| 105 | 24,717 | 397 | 4,943 | Running |
| 120 | - | - | - | **CRASHED** |

**Failure Mode:**
- **Exit code:** 137
- **Reason:** "OutOfMemoryError: Container killed due to memory usage"
- **Result:** 502 Bad Gateway responses to clients
- **ECS behavior:** Automatically restarted crashed tasks
- **User impact:** Request failures, service degradation

*Screenshot: `buggy_aws_memory_leak_and_crash.png`*  
*Screenshot: `buggy_locust_failures.png`*  
*Screenshot: `buggy_ecs_task_oom_killed.png`*

---

## Root Cause Analysis

**Why Health Checks Didn't Help:**

The ALB health checks continued to pass (`/health` endpoint returned 200 OK) even while goroutines leaked memory in the background. Health checks operate at the infrastructure level, detecting whether the container process is responsive, but they cannot detect application-level resource leaks that accumulate over time.

**The Failure Pattern:**
1. Each `/products/analyze/:id` request spawned a goroutine
2. Goroutines ran infinite loops, never exiting
3. Each goroutine allocated 5 MB/second continuously
4. With 10 concurrent Locust users hitting the endpoint 10x per second, leak rate reached 50+ MB/second per task
5. 512 MB memory limit exhausted in ~10 seconds per task
6. Linux OOM killer terminated the container
7. ECS detected task exit and restarted it
8. Cycle repeated, causing continuous availability issues

**Why This Matters in Distributed Systems:**

In a distributed system with multiple instances behind a load balancer, this type of failure can cause cascading problems. As tasks crash and restart, remaining healthy tasks receive more traffic, accelerating their memory exhaustion. This creates a "thundering herd" scenario where all instances crash in rapid succession, leading to complete service outage despite having redundancy and auto-scaling configured.

---

## The Fix: Proper Goroutine Lifecycle Management

### Implementation Approach

The fix implements **bounded goroutine lifetimes** using Go's context package and timeout mechanisms.

**Fixed Code:**
```go
router.POST("/products/analyze/:id", func(c *gin.Context) {
    id := c.Param("id")
    
    go func() {
        // Create 5-second timeout context
        ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
        defer cancel()
        
        ticker := time.NewTicker(500 * time.Millisecond)
        defer ticker.Stop()
        
        workCount := 0
        for workCount < 10 {
            select {
            case <-ctx.Done():
                // Timeout - exit cleanly
                return
            case <-ticker.C:
                // Do work
                _ = make([]byte, 100*1024) // 100KB (not 5MB!)
                workCount++
            }
        }
        // Work complete - goroutine exits
    }()
    
    c.JSON(200, gin.H{"message": "Analysis started", "product_id": id})
})
```

**Key Improvements:**
1. **Timeout-based termination:** Goroutines automatically exit after 5 seconds maximum
2. **Bounded work:** Each goroutine performs exactly 10 iterations then exits
3. **Reduced memory footprint:** 100 KB allocations instead of 5 MB
4. **Context cancellation:** Proper cleanup with `defer cancel()` and `defer ticker.Stop()`
5. **Select statement:** Allows goroutine to respond to cancellation signals

### Failure Handling Pattern: Fail-Fast with Resource Bounds

This fix implements the **fail-fast** pattern combined with **bulkhead isolation**:

- **Fail-fast:** Goroutines complete quickly (5 seconds max) rather than accumulating indefinitely
- **Bulkhead:** Each goroutine has bounded resource consumption (500 KB max over 5 seconds)
- **Graceful degradation:** If the system becomes overloaded, goroutines timeout and exit rather than accumulating until crash

---

## Evidence of Stability

### Fixed Version Performance Under Identical Load

**Test Configuration:**
- Same Locust settings: 10 users, spawn rate 2
- Same endpoints exercised
- Same ECS configuration: 512 MB memory limit

**Observed Behavior:**

**Memory remains stable:**
- Range: 1-3 MB throughout test
- Compare to buggy: grew from 431 MB → 24,717 MB
- **Result:** 99.9% reduction in memory footprint

**Goroutines remain bounded:**
- Range: 79-99 goroutines
- Fluctuates as goroutines spawn and complete
- Compare to buggy: grew from 51 → 397 monotonically
- **Result:** Goroutines complete and are garbage collected

**No crashes or errors:**
- Test duration: 3+ minutes continuous load
- 502/504 errors: 0
- Task restarts: 0
- **Result:** 100% availability maintained

*Screenshot: `fixed_aws_stable_metrics.png`*  
*Screenshot: `fixed_locust_stable_no_failures.png`*

### Performance Comparison

| Metric | Buggy Version | Fixed Version | Improvement |
|--------|---------------|---------------|-------------|
| Memory at 90s | 19,491 MB | 1-2 MB | 99.99% reduction |
| Goroutines at 90s | 366 (growing) | 80-95 (stable) | Bounded |
| Time to crash | ~120 seconds | No crash observed | Infinite improvement |
| Availability | Crashed repeatedly | 100% uptime | Complete stability |
| Request failures | 488 errors | 0 errors | 100% success rate |

---

## Key Learnings

### 1. Health Checks vs. Application-Level Failure Handling

**What health checks detect:**
- Container process crashes
- Unresponsive endpoints (timeouts)
- Complete node failures

**What health checks miss:**
- Resource leaks accumulating over time
- Goroutine/thread leaks
- Memory leaks that don't immediately crash the process
- Slow degradation in performance
- Partial failures (some endpoints work, others don't)

**The gap:** Health checks operate at infrastructure level (is the container alive?) but cannot detect application-level problems until they cause infrastructure failure. By then, the application may have already served degraded or incorrect responses to users.

### 2. Importance of Resource Lifecycle Management

In concurrent systems, every spawned execution unit (goroutine, thread, process) must have:
- **Clear termination conditions:** When should it stop?
- **Cleanup mechanisms:** How to release resources when done?
- **Timeout bounds:** Maximum execution time to prevent runaway processes
- **Cancellation support:** Ability to be stopped externally if needed

The buggy code violated all four principles. The fixed code implements all four.

### 3. Observability and Metrics

The custom `/metrics` endpoint proved essential for diagnosing the problem. Standard health checks would have shown "healthy" until the crash, providing no early warning. Application-level metrics exposed:
- Goroutine count trends
- Memory allocation patterns
- Resource leak detection (leaked_chunks counter)

In production systems, such metrics enable:
- **Proactive alerting:** Detect leaks before crashes occur
- **Capacity planning:** Understand normal vs. abnormal resource consumption
- **Root cause analysis:** Identify which operations cause resource issues

### 4. Distributed Systems Failure Modes

This experiment demonstrated several distributed systems concepts:

**Partial failure:** Individual ECS tasks crashed while others continued operating. The ALB routed traffic only to healthy tasks, maintaining partial availability. However, as tasks crashed successively, overall capacity degraded until complete service failure.

**Cascading failure:** As tasks crashed, remaining tasks received more traffic, accelerating their memory exhaustion. Without the fix, all tasks eventually crashed despite auto-scaling attempts to add capacity.

**Recovery mechanisms:** ECS automatically restarted crashed tasks, but without fixing the underlying bug, tasks entered a crash loop. Automatic restart without bug fixes can mask problems in monitoring while continuously degrading user experience.

---

## Conclusions

This experiment reinforced that **building reliable distributed systems requires multiple layers of defense:**

1. **Infrastructure level:** Health checks, auto-scaling, automatic restarts (provided by ECS/ALB)
2. **Application level:** Proper resource management, timeouts, bounded execution (must be implemented in code)
3. **Observability:** Metrics and monitoring to detect problems before they cause failures

Infrastructure-level mechanisms like health checks and auto-scaling are necessary but insufficient. They can detect and recover from failures after they occur, but they cannot prevent application-level bugs from causing failures in the first place. Proper application design with explicit resource lifecycle management, timeout bounds, and graceful degradation is essential for building truly resilient distributed systems.

The fail-fast pattern implemented in the fix exemplifies good distributed systems design: operations complete quickly with bounded resource consumption, preventing resource accumulation that could destabilize the entire service. Combined with infrastructure-level resilience mechanisms, this approach provides defense in depth against failures in distributed environments.

---

## References

**Code Repository:**
- Buggy version: `midterm/part2-crash-recovery/buggy-version/`
- Fixed version: `midterm/part2-crash-recovery/fixed-version/`
- Infrastructure: `midterm/part2-crash-recovery/terraform/`

**Screenshots:**
- Local testing: `buggy_local_test_memory_leak_4gb.png`, `buggy_local_test_continuous_memory_growth.png`
- AWS buggy version: `buggy_aws_memory_leak_and_crash.png`, `buggy_locust_failures.png`, `buggy_ecs_task_oom_killed.png`
- AWS fixed version: `fixed_aws_stable_metrics.png`, `fixed_locust_statistics.png`

**Failure Handling Patterns Referenced:**
- Fail-fast (Sam Newman, Building Microservices)
- Bulkhead pattern (resource isolation)
- Context-based cancellation (Go concurrency patterns)
