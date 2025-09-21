# Locust Load Testing - Analysis

## Experimental Setup
- **Server:** Go with Gin framework (album API)
- **Test Duration:** 3 minutes per test for consistent comparison
- **Load Pattern:** 50 users, 10 users/second ramp-up
- **Request Ratio:** ~3:1 GET:POST operations
- **Host:** Docker containers → Go server on localhost:8080

## Complete Test Results Summary

| Test Configuration | Workers | Total Requests | RPS | GET /albums Avg | POST /albums Avg | Aggregated Avg |
|-------------------|---------|----------------|-----|-----------------|------------------|----------------|
| **1 User Baseline** | 1 | 120 | 0.7 | 6.13ms | 3.11ms | 4.42ms |
| **50 Users, 1 Worker** | 1 | 5,223 | 32.7 | 7.12ms | 2.37ms | 4.45ms |
| **50 Users, 4 Workers** | 4 | 117 | 0.7 | 9.42ms | 2.74ms | 5.33ms |
| **50 Users, 4 Workers (Full)** | 4 | 5,210 | 32.8 | 10.48ms | 2.75ms | 5.79ms |
| **FastHttpUser, 4 Workers** | 4 | 5,194 | 33.0 | 13.88ms | 2.03ms | 6.99ms |

## Locust Analysis: GET vs POST Performance

### Which operations will be most common in real world scenarios?

**Real-world patterns typically show:**
- **Read-heavy workloads:** 80-95% reads, 5-20% writes
- **E-commerce:** 100:1 to 1000:1 read-to-write ratios
- **Social media:** High read volume for browsing, occasional posts/updates
- **APIs:** GET requests dominate for data retrieval, POST/PUT for updates

### How does this impact the data structure you are using to save your data?

**Current Implementation Analysis:**
- **Data Structure:** Simple Go slice `[]album` (in-memory)
- **GET /albums:** Returns entire slice - O(1) reference but O(n) serialization
- **POST /albums:** Appends to slice - O(1) amortized insertion
- **GET /albums/:id:** Linear search through slice - O(n) lookup

**Performance Impact:**
- **Slice grows with each POST** → GET /albums response payload increases
- **No indexing** → Individual album lookups are inefficient
- **Memory-only storage** → All data lost on restart

**Real-world improvements for read-heavy workloads:**
- **Indexed data structures:** Hash maps for O(1) ID lookups
- **Database with indexes:** B-tree indexes for fast searches
- **Caching layers:** Redis/Memcached for frequently accessed data
- **Read replicas:** Separate read/write database instances

### What is going on here? Can you argue reasons behind different numbers?

**Counter-intuitive Result: POST Outperforms GET Under Load**

**1-Worker vs 4-Worker Comparison:**
- **GET /albums:** 7.12ms → 10.48ms (47% slower with 4 workers)
- **POST /albums:** 2.37ms → 2.75ms (16% slower with 4 workers)

**Why POST is consistently faster:**
1. **Fixed computational cost:** JSON parsing and slice append are constant-time operations
2. **Small response payload:** Returns single created album (fixed size ~100 bytes)
3. **No growing serialization cost:** Response size doesn't increase with dataset size

**Why GET /albums becomes the bottleneck:**
1. **Growing response payload:** Must serialize entire album list (grows with each POST)
2. **Memory allocation pressure:** Large object creation under concurrent load
3. **JSON marshaling overhead:** Serialization cost increases linearly with data size
4. **CPU-bound operation:** String formatting and JSON encoding dominate

**Individual GET operations (GET /albums/1-3):**
- Remain fast (1.68-2.21ms) due to small, fixed response size
- Linear search overhead minimal with only 3 base albums

## Amdahl's Law Analysis: Worker Scaling

### 1 Worker vs 4 Workers Performance Comparison

**Throughput Analysis:**
- **1 Worker:** 32.7 RPS
- **4 Workers:** 32.8 RPS
- **Scaling Efficiency:** 1.003x (essentially no improvement)

**Are the throughputs making sense?**

The results demonstrate **perfect Amdahl's Law behavior** - adding 4x workers provides virtually no throughput improvement because:

1. **Single bottleneck:** One Go server instance handles all requests
2. **Serial processing:** Go server processes requests sequentially within each handler
3. **Shared resource contention:** All workers compete for the same server resources

**Does throughput change linearly with workers?**

**No - it remains virtually flat.** This is classic Amdahl's Law:
- **Parallel portion (P):** Locust workers generating requests = nearly 100% parallel
- **Serial portion (S):** Single Go server handling requests = the bottleneck
- **Maximum speedup = 1 / S ≈ 1** (no improvement possible)

**Hashmap reading/writing contribution:**

While our implementation uses a slice, the concept applies to hashmaps:
1. **Concurrent map access** would require synchronization (mutex/locks)
2. **Lock contention** increases with worker count
3. **Cache thrashing** when multiple cores access shared memory
4. **Context switching overhead** between OS threads

The single Go server instance eliminates these distributed coordination costs but creates a singular bottleneck.

## Context Switching: HttpUser vs FastHttpUser

### Performance Comparison

**HttpUser (Python requests library):**
- **RPS:** 32.8
- **Average Response Time:** 5.79ms
- **GET /albums:** 10.48ms average

**FastHttpUser (C-based uvloop):**
- **RPS:** 33.0 (0.6% improvement)
- **Average Response Time:** 6.99ms (21% worse)
- **GET /albums:** 13.88ms average (32% worse)

### What do you observe?

**Unexpected Result: FastHttpUser performed worse**, contradicting expectations.

### Research and Reasons Behind Results

**Why FastHttpUser didn't improve performance:**

1. **Server bottleneck dominates:** The Go server, not HTTP client, limits throughput
2. **Network overhead minimal:** Local testing (localhost) eliminates network latency benefits
3. **Response processing cost:** Parsing larger JSON responses may offset client improvements
4. **Context switching overhead:** More aggressive request generation may increase contention

**When FastHttpUser typically excels:**
- **Network-bound scenarios:** High latency networks where connection overhead matters
- **High-frequency, small requests:** Microservice architectures with many small calls
- **CPU-bound clients:** When request generation, not server processing, is the bottleneck

**Our experimental conditions favor neither:**
- **Localhost testing:** No network latency to optimize
- **Server-bound:** Single Go instance handles ~33 RPS maximum
- **Growing response payloads:** JSON parsing overhead increases with dataset size

## Key Distributed Systems Lessons

### Bottleneck Identification
The experiments reveal that **identifying the true bottleneck** is crucial in distributed systems:
- Adding parallel workers (Locust) didn't help when the server was the constraint
- Optimizing HTTP clients didn't help when server processing dominated
- The weakest link determines overall system performance

### Scalability Patterns
1. **Horizontal scaling only works when components can scale independently**
2. **Shared resources create natural bottlenecks** (single database, single server)
3. **Amdahl's Law applies to distributed systems** - serial components limit parallel benefits

### Real-World Applications
- **Database sharding:** Eliminate single database bottlenecks
- **Load balancing:** Distribute server load across multiple instances  
- **Caching strategies:** Reduce load on bottleneck resources
- **Asynchronous processing:** Decouple request handling from heavy processing

### Data Structure Impact on Performance
The choice of simple slice vs indexed structures becomes critical at scale:
- **Read-heavy workloads benefit from indexed access patterns**
- **Write-heavy workloads need efficient append/insert operations**
- **Hybrid approaches** (write-optimized log + read-optimized indexes) handle mixed workloads

The experimental results provide concrete evidence that distributed systems performance is determined by bottlenecks, not just parallelization, and that data structure choices significantly impact scalability patterns.