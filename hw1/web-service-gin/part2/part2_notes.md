## Virtual Machines and Cloud Computing

### What is a Virtual Machine?
A Virtual Machine (VM) is a software-based computer that runs on physical hardware but operates as if it's a separate, independent machine. It includes:
- Virtual CPU, memory, storage, and network interfaces
- Its own operating system (guest OS) running on top of a hypervisor
- Isolation from other VMs on the same physical hardware

### Running Programs on VM vs Locally

**Local Execution:**
- Programs run directly on your physical hardware
- Direct access to CPU, RAM, and system resources
- Limited by your machine's specifications
- Single point of failure (your computer)

**VM Execution:**
- Programs run in virtualized environment
- Resources are allocated from a pool managed by hypervisor
- Can scale resources up/down as needed
- Multiple VMs can run on powerful server hardware
- Geographic distribution possible
- Built-in redundancy and backup capabilities

## Network Security and Access Control

### IP Address Changes and SSH Access
When your IP address changes, you need to:
1. **Update Security Group Rules**: Modify the inbound rule for SSH (port 22) to allow your new IP
2. **Options for IP management**:
   - Use `0.0.0.0/0` (allows access from anywhere - less secure)
   - Update with your new specific IP address
   - Use your organization's IP range if available

### EC2 IP Address Management
**Problem**: EC2 instances get new public IP addresses when stopped/started

**Solution - Elastic IP Address**:
- Static IP that persists across instance restarts
- Costs money when not attached to running instance
- Provides consistent endpoint for your applications
- Alternative: Use DNS names or load balancers for production

## AWS Instance Types and Service Levels

### t2.micro Instance Specifications
- **vCPU**: 1 virtual CPU (variable performance)
- **Memory**: 1 GB RAM
- **Network**: Low to Moderate bandwidth
- **Storage**: EBS-optimized available
- **CPU Credits**: Burstable performance model

### Why These Specs Matter
- **Development**: Sufficient for learning and small applications
- **Production Limitations**: 
  - Memory constraints for large applications
  - CPU throttling under sustained load
  - Network bandwidth limits for high-traffic apps
- **Cost Optimization**: Free tier eligible, predictable costs
- **Scaling Path**: Easy to upgrade to larger instances

## GCP vs AWS Comparison

### Google Cloud Platform (GCP)
**Advantages**:
- Cloud Shell provides instant development environment
- Pre-configured with common tools (Go, Python, git, etc.)
- No local setup required
- Integrated with Google services

**Process**:
1. Open Cloud Shell in browser
2. Clone/create project directly
3. Run applications immediately
4. Built-in editor and terminal

### Amazon Web Services (AWS)
**More Complex Setup**:
- Manual EC2 instance creation
- Security group configuration required
- SSH key management
- Cross-compilation needed for deployment
- Manual file transfer via SCP

**More Control**:
- Full control over instance configuration
- Detailed networking and security options
- More instance type choices
- Industry standard for enterprise

## Testing Methodology

### API Testing with curl
**Endpoints Tested**:
```bash
# Get all albums
curl http://ec2-ip:8080/albums

# Create new album
curl http://ec2-ip:8080/albums \
  --header "Content-Type: application/json" \
  --request "POST" \
  --data '{"id": "4", "title": "Song", "artist": "Artist", "price": 29.99}'

# Get specific album
curl http://ec2-ip:8080/albums/2
```

### Performance Testing Approach
- **Duration**: 30-second load test
- **Metrics Collected**: Response time per request
- **Analysis**: 
  - Response time distribution (histogram)
  - Performance over time (scatter plot)
  - Statistical analysis (mean, median, percentiles)
- **Key Findings**: Demonstrated "long tail" latency distribution

### Testing Strategy Benefits
- **Lightweight**: No complex testing framework needed
- **Realistic**: Tests actual HTTP endpoints
- **Scriptable**: Can automate and repeat tests
- **Observable**: Clear output for debugging

## Key Takeaways

1. **Cloud Complexity**: AWS provides more control but requires more setup compared to GCP
2. **Infrastructure Matters**: t2.micro sufficient for learning but has real limitations
3. **Security Considerations**: Network access control is critical and complex
4. **Performance Characteristics**: Real applications show variable response times
5. **Development Workflow**: Multiple tools and environments needed for full deployment