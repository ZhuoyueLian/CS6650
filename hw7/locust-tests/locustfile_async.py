from locust import HttpUser, task, between
import random
import json

class AsyncOrderUser(HttpUser):
    """
    Tests the async order endpoint - should accept all orders immediately
    """
    wait_time = between(0.1, 0.5)
    
    @task
    def create_order_async(self):
        """
        POST to /orders/async endpoint
        Should return immediately with 202 Accepted
        """
        order_data = {
            "customer_id": random.randint(1, 10000),
            "items": [
                {
                    "product_id": random.randint(1, 100),
                    "quantity": random.randint(1, 5),
                    "price": round(random.uniform(10.0, 500.0), 2)
                }
                for _ in range(random.randint(1, 3))
            ]
        }
        
        with self.client.post(
            "/orders/async",
            json=order_data,
            catch_response=True,
            name="/orders/async"
        ) as response:
            if response.status_code == 202:
                response.success()
            else:
                response.failure(f"Failed with status {response.status_code}")


# To run flash sale test:
# locust -f locustfile_async.py --host=http://YOUR-ALB-URL --users=20 --spawn-rate=10 --run-time=60s --headless