# Distributed Systems for Fun and Profit
## Introduction and Chapter 1 - Key Concepts

## Introduction - Core Concepts

### Two Fundamental Constraints of Distributed Systems
- **Information travels at the speed of light**
- **Independent things fail independently**

### Main Goal
Bring together ideas behind modern distributed systems:
- Amazon's Dynamo
- Google's BigTable and MapReduce  
- Apache's Hadoop

### Focus
Distributed programming dealing with:
- **Distance** (information travel limitations)
- **Having multiple components** (coordination challenges)

---

## Chapter 1 - Key Points

### Why Use Distributed Systems?
- **Single computer limitations:** Cost and hardware limits
- **Commodity hardware advantage:** Often better value than high-end systems
- **Performance insight:** Gap between high-end/commodity hardware decreases with cluster size

### Core Goals

#### Scalability
Handle growing workload without degrading performance

#### Performance/Latency  
- Speed of light sets minimum latency limits
- Cannot be overcome with financial resources

#### Availability
- Proportion of time system functions properly
- **99.9% = 9 hours downtime per year**
- **99.99% = less than 1 hour downtime per year**

#### Fault Tolerance
System behaves in well-defined manner when components fail

### Physical Constraints
1. **Number of nodes** (increases failure probability)
2. **Distance between nodes** (increases latency)

### Two Main Design Techniques

#### Partitioning
- Split data across nodes for parallel processing
- Improves performance by limiting data examined
- Improves availability through independent failure

#### Replication  
- Copy data to multiple nodes
- Provides fault tolerance and performance benefits
- Creates consistency challenges

### Key Trade-offs
- **Understandability vs Performance:** Systems that hide complexity are easier to understand, but exposing details may improve performance
- **Replication Paradox:** Can build reliable systems from unreliable components through redundancy

### Important Insight
Distributed systems can achieve higher reliability than individual components by designing for partial failures rather than trying to prevent all failures.