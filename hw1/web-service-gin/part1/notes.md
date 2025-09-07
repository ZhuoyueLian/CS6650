## 1. Writing programs with Golang.
### 1.1. What does `go mod init` do?  
`go mod init` initializes a new Go module by creating a go.mod file in the current directory. This file:
1. Declares the module path (like example/web-service-gin)
2. Tracks dependencies the  project uses
3. Specifies the Go version
4. Acts as the root of the project's dependency management

Think of it as creating a "project manifest" that tells Go how to manage the code and its external libraries.

### 1.2. What does `go get .` do?
`go get .` downloads and installs all dependencies listed in the `go.mod` file for the current directory (the dot). It:
1. Reads the import statements in Go files
2. Downloads missing packages (like github.com/gin-gonic/gin)
3. Updates `go.mod` and creates/updates `go.sum` (dependency lock file)
4. Makes dependencies available for the code to use

## 2. Structuring server code as a RESTful API. 
RESTful APIs follow specific conventions:
- Resources: Represented by URLs (`/albums, /albums/:id`)
- HTTP Methods: Different actions on resources
    - GET: Retrieve data
    - POST: Create new data
    - PUT/PATCH: Update existing data
    - DELETE: Remove data
- Stateless: Each request contains all needed information
- JSON: Standard data exchange format

In Gin code:
```go
router.GET("/albums", getAlbums)        // Get all albums
router.POST("/albums", postAlbums)      // Create new album
router.GET("/albums/:id", getAlbumByID) // Get specific album
```

## 3. What `localhost` means, what a subnet is used for, and the difference between running on your machine versus the Google Cloud Platform. 
### **Localhost**
- `localhost` or `127.0.0.1` refers to your own machine
- Traffic never leaves your computer
- Only you can access services running on localhost
- Used for development and testing

### **Subnets**
A subnet is a logical subdivision of a network that:
- Groups related devices together
- Controls traffic flow between network segments
- Provides security boundaries
- Enables efficient routing

### **Local Machine vs Google Cloud Platform**
**Local Machine:**
- Code runs on your hardware
- Limited by your computer's resources
- Only accessible from your network
- No redundancy or scaling

**Google Cloud Platform:**
- Code runs on Google's infrastructure
- Scalable resources (CPU, memory, bandwidth)
- Globally accessible
- Built-in redundancy and reliability
- Managed services (load balancing, monitoring)

## 4. How to use the "flow" of using multiple terminal windows, and very lightweight testing with curl.
**Terminal Workflow**
1. Terminal 1: Run your server
```bash
go run .
```
Keep this running to serve requests

2. Terminal 2: Test with curl
```bash
curl http://localhost:8080/albums
```

3. Terminal 3 (optional): Monitor logs, run additional commands

**curl Testing Commands**

**Get all albums:**
```bash
curl http://localhost:8080/albums
```

**Add a new album:**
```bash
curl http://localhost:8080/albums \
  --header "Content-Type: application/json" \
  --request "POST" \
  --data '{"id": "4", "title": "Kind of Blue", "artist": "Miles Davis", "price": 45.99}'
```

**Get specific album:**
```bash
curl http://localhost:8080/albums/2
```

**Check response headers:**
```bash
curl --include http://localhost:8080/albums
```

This workflow:
1. Keeps the server running continuously
2. Tests different endpoints quickly
3. Sees real-time server responses
4. Debugs issues as they occur
5. Simulates how a frontend application would interact with the API

The key advantage of curl is its simplicity for API testing - quickly verify endpoints work correctly without building a frontend interface.