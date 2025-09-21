# Atomicity Experiment - Observations

## 1. What values do you see?

**Atomic counter:**
- Always shows **50,000** (consistent across all runs)

**Regular counter:**
- Shows different values **< 50,000** each time:
  - Run 1: 33,703
  - Run 2: 31,685  
  - Run 3: 34,098
  - Run 4: 31,774
  - Run 5: 37,915
  - Range: 31,685 to 37,915 (losing 12,085 to 18,315 increments each run)

## 2. What is happening?

**For the atomic counter:**
The atomic operations guarantee that each increment is completed as a single, indivisible unit. When `atomicOps.Add(1)` is called, the entire read-modify-write operation happens atomically, meaning no other goroutine can interfere with it. This ensures all 50,000 increments are properly counted.

**For the regular counter:**
A race condition occurs because `regularOps++` is **not** an atomic operation. It actually consists of three separate steps:
1. **READ** the current value from memory
2. **ADD** 1 to that value  
3. **WRITE** the result back to memory

When multiple goroutines execute these steps simultaneously, they can interleave in problematic ways. For example:
- Goroutine A reads `regularOps` (value: 100)
- Goroutine B reads `regularOps` (value: 100) ← same value!
- Goroutine A calculates 100 + 1 = 101
- Goroutine B calculates 100 + 1 = 101  
- Goroutine A writes 101
- Goroutine B writes 101 ← overwrites A's increment!

Result: Two increments happened, but the counter only increased by 1. This "lost update" problem occurs thousands of times during execution, explaining the reason why losing 12,000-18,000 increments.

## 3. Try running with the -race flag. What does that do?

The `-race` flag enables Go's **race detector**, a powerful debugging tool that:

### What it detects:
- Monitors memory access patterns during program execution
- Identifies when multiple goroutines access the same memory location simultaneously
- Specifically looks for cases where at least one access is a write operation

### What it reports:
- **Location**: Shows exactly which line of code has the race (line 38: `regularOps++`)
- **Goroutines involved**: Identifies which specific goroutines are conflicting
- **Type of conflict**: Shows read-after-write and write-after-write races
- **Stack traces**: Provides the call stack showing where each goroutine was created

### From the output:
```
WARNING: DATA RACE
Read at 0x00c00038e028 by goroutine 60:
Previous write at 0x00c00038e028 by goroutine 59:
```

This shows that goroutine 60 tried to read from the same memory address that goroutine 59 was writing to, creating a data race.

### Important note:
The race detector adds significant runtime overhead (can slow programs by 5-10x), so it's used for testing/debugging, not production. It also terminates the program with exit status 66 when races are found, which is why seeing that status code.

The race detector found **no races** in the atomic counter section because atomic operations are properly synchronized.

---

## Key Takeaway
This demonstrates a fundamental principle in distributed systems: **concurrent access to shared state requires proper synchronization mechanisms**. This same concept applies when multiple nodes in a distributed system try to update shared data.