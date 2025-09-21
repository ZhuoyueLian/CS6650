from locust import FastHttpUser, task, between
import json
import random

class FastAlbumUser(FastHttpUser):
    """Fast HTTP user for high-performance testing"""
    wait_time = between(1, 2)
    
    def on_start(self):
        """Called when a user starts"""
        print("Starting fast album user simulation")
    
    @task(3)  # Weight of 3 - this runs 3x more often than POST
    def get_albums(self):
        """GET request to fetch all albums"""
        response = self.client.get("/albums")
        
    @task(3)  # Weight of 3 - GET individual album
    def get_album_by_id(self):
        """GET request to fetch album by ID"""
        # Only test with existing album IDs (1, 2, 3) to avoid 404 failures
        album_id = random.choice(["1", "2", "3"])
        response = self.client.get(f"/albums/{album_id}")
        
    @task(1)  # Weight of 1 - this creates 3:1 GET:POST ratio
    def post_album(self):
        """POST request to create a new album"""
        # Generate random album data
        album_id = str(random.randint(1000, 9999))
        artists = ["Miles Davis", "Charlie Parker", "Billie Holiday", "Duke Ellington", "Ella Fitzgerald"]
        titles = ["Cool Jazz", "Bebop Blues", "Smooth Sax", "Piano Dreams", "Vocal Magic"]
        
        new_album = {
            "id": album_id,
            "title": random.choice(titles) + f" #{album_id}",
            "artist": random.choice(artists),
            "price": round(random.uniform(15.99, 89.99), 2)
        }
        
        response = self.client.post("/albums", json=new_album)