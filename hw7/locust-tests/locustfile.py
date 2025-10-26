from locust import HttpUser, task, between
import random
import json

class OrderUser(HttpUser):
    """
    Simulates customers placing orders during normal and flash sale conditions
    """
    wait_time = between(0.1, 0.5)  # Random wait 100-500ms between requests
    
    @task
    def create_order_sync(self):
        """
        POST to /orders/sync endpoint
        Simulates synchronous order processing
        """
        order_data = {
            "customer_id": random.randint(1, 10000),
            "items": [
                {
                    "product_id": random.randint(1, 100),
                    "quantity": random.randint(1, 5),
                    "price": round(random.uniform(10.0, 500.0), 2)
                }
                for _ in range(random.randint(1, 3))  # 1-3 items per order
            ]
        }
        
        with self.client.post(
            "/orders/sync",
            json=order_data,
            catch_response=True,
            name="/orders/sync"
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Failed with status {response.status_code}")


# To run tests:
# 
# Normal Operations (5 users, 30 seconds):
#   locust -f locustfile.py --host=http://YOUR-ALB-URL --users=5 --spawn-rate=1 --run-time=30s --headless
#
# Flash Sale (20 users, 60 seconds):
#   locust -f locustfile.py --host=http://YOUR-ALB-URL --users=20 --spawn-rate=10 --run-time=60s --headless