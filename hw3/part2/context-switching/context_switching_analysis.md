# Context Switching Experiment - Analysis

## Experimental Data Summary

Based on 5 runs of 1,000,000 ping-pong exchanges (2,000,000 total context switches) on a 12-core system:

| Run | Single-Thread Time | Single-Thread Switch | Multi-Thread Time | Multi-Thread Switch | Winner |
|-----|-------------------|---------------------|-------------------|-------------------|---------|
| 1 | 639.96ms | 319ns | 896.70ms | 448ns | Single (1.40x faster) |
| 2 | 568.30ms | 284ns | 588.72ms | 294ns | Single (1.04x faster) |
| 3 | 554.18ms | 277ns | 610.07ms | 305ns | Single (1.10x faster) |
| 4 | 638.69ms | 319ns | 592.50ms | 296ns | **Multi (1.08x faster)** |
| 5 | 556.24ms | 278ns | 593.79ms | 296ns | Single (1.07x faster) |
| **Average** | **591.48ms** | **295ns** | **656.36ms** | **328ns** | **Single (1.11x faster)** |

**Overall Result:** Single-threaded goroutine switching is 9.9% faster than multi-threaded switching.

## Record and Compare the Two Averages

**Single-thread average:** 591.48ms (295ns per context switch)
**Multi-thread average:** 656.36ms (328ns per context switch)

## Which One is Faster? Why?

**Single-threaded switching is faster** by 1.11x (9.9% improvement).

**Why single-threaded was faster:**

Single-threaded goroutine switching operates entirely within Go's user-space scheduler. When `GOMAXPROCS(1)` is set, all goroutines run on a single OS thread, eliminating the overhead of:
- OS-level thread scheduling and context switches
- CPU cache invalidation between different cores
- Memory synchronization barriers
- Cross-core coordination overhead

The multi-threaded approach allows goroutines to run on different OS threads across multiple CPU cores. While this enables true parallelism for CPU-bound tasks, it introduces overhead for coordination-heavy workloads like ping-pong message passing:
- Goroutines may be scheduled on different OS threads, requiring kernel-level context switches
- CPU caches must be synchronized between cores
- The Go runtime scheduler must coordinate with the OS scheduler

For this specific ping-pong pattern, the coordination overhead outweighs any parallelism benefits, making single-threaded execution more efficient.

## How Does This Relate to Context Switching Between Processes, Containers, and Virtual Machines?

The context switching costs form a hierarchy where each level adds significant overhead:

**Context Switching Cost Hierarchy:**

| Abstraction Level | Approximate Switch Time | Context Size | Overhead Factor |
|-------------------|------------------------|--------------|-----------------|
| **Goroutine** (measured) | ~295ns | ~2KB stack | 1x (baseline) |
| **OS Thread** | ~1-10μs | Registers + larger stack | 10-100x |
| **Process** | ~10-100μs | Full memory space + file descriptors | 100-1000x |
| **Container** | ~100μs-1ms | Process + namespaces + cgroups | 1000-10000x |
| **Virtual Machine** | ~1-10ms | Full OS state + hardware virtualization | 10000-100000x |

**Key Relationships:**

**Isolation vs Performance Trade-off:** Each abstraction level provides stronger isolation boundaries but at exponentially increasing performance costs. The 295ns goroutine switch represents the lightest form of context switching with minimal isolation.

**Distributed Systems Implications:** Understanding these local coordination costs helps explain why distributed systems face such significant performance challenges. If local goroutine coordination costs 295ns, network communication typically costs milliseconds - roughly 10,000-100,000x more expensive.

**Resource Overhead:** The progression from goroutines to VMs shows how context size grows dramatically. Goroutines share memory space and have minimal state, while VMs must save and restore entire operating system states.

This hierarchy explains why:
- Microservices architectures (process/container boundaries) have significant performance overhead compared to monoliths (goroutine boundaries)
- Container orchestration systems must carefully manage scheduling to minimize context switching
- Virtual machine migration is expensive compared to process migration
- System designers choose the minimal isolation level needed for their security and reliability requirements