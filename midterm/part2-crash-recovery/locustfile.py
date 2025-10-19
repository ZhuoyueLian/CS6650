from locust import HttpUser, task, between
import random

class ProductUser(HttpUser):
    wait_time = between(0.1, 0.3)
    
    @task(10)
    def analyze_product(self):
        """This endpoint leaks memory in the buggy version"""
        product_id = random.randint(1, 100)
        self.client.post(
            f"/products/analyze/{product_id}",
            name="/products/analyze/[id]"
        )
    
    @task(3)
    def create_product(self):
        product_id = random.randint(1, 1000)
        self.client.post(
            f"/products/{product_id}",
            json={
                "id": product_id,
                "name": f"Product {product_id}",
                "description": "Test product",
                "price": 99.99
            },
            name="/products/[id]"
        )
    
    @task(1)
    def get_metrics(self):
        """Check how many goroutines are running"""
        self.client.get("/metrics")