from locust import HttpUser, task, between
import json
import random

class AlbumUser(HttpUser):
    wait_time = between(1, 2)  # Wait 1-2 seconds between requests
    
    def on_start(self):
        """Called when a user starts"""
        print("Starting album user simulation")
    
    @task(3)  # Weight of 3 - this runs 3x more often than POST
    def get_albums(self):
        """GET request to fetch all albums"""
        response = self.client.get("/albums")
        if response.status_code == 200:
            # Optional: parse and validate response
            albums = response.json()
            print(f"GET /albums returned {len(albums)} albums")
    
    @task(3)  # Weight of 3 - GET individual album
    def get_album_by_id(self):
        """GET request to fetch album by ID"""
        # Test with existing album IDs (1, 2, 3) and some that might not exist
        album_id = random.choice(["1","2","3"])
        response = self.client.get(f"/albums/{album_id}")
        if response.status_code == 200:
            album = response.json()
            print(f"GET /albums/{album_id} found: {album.get('title', 'Unknown')}")
        elif response.status_code == 404:
            print(f"GET /albums/{album_id} not found (expected)")
    
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
        
        response = self.client.post("/albums", 
                                  json=new_album,
                                  headers={"Content-Type": "application/json"})
        
        if response.status_code == 201:
            created_album = response.json()
            print(f"POST /albums created: {created_album.get('title', 'Unknown')}")
        else:
            print(f"POST /albums failed with status: {response.status_code}")

# Alternative FastHttpUser version for performance testing
from locust import FastHttpUser

class FastAlbumUser(FastHttpUser):
    """Fast HTTP user for high-performance testing"""
    wait_time = between(1, 2)
    
    @task(3)
    def get_albums(self):
        response = self.client.get("/albums")
        
    @task(3) 
    def get_album_by_id(self):
        album_id = random.choice(["1","2","3"])
        response = self.client.get(f"/albums/{album_id}")
        
    @task(1)
    def post_album(self):
        album_id = str(random.randint(1000, 9999))
        new_album = {
            "id": album_id,
            "title": f"Test Album {album_id}",
            "artist": "Test Artist",
            "price": 29.99
        }
        
        response = self.client.post("/albums", json=new_album)