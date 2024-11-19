import random
import os
from dotenv import load_dotenv
from locust import HttpUser, task, between, SequentialTaskSet

load_dotenv()

def fetch_access_token(self, scope):
    """Fetch the access token when a new user starts."""
    # Replace with your OAuth2 token URL
    token_url = "/oauth/token"

    client_id = os.environ.get("CLIENT_ID")
    client_secret = os.environ.get("CLIENT_SECRET")
    
    # Request access token
    response = self.client.post(token_url, data={
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_secret": client_secret,
        "scope": scope
    })

    if response.status_code == 200:
        return response.json()["access_token"]
    else:
        self.interrupt()  # Stop the user if we can't authenticate
        return None

class HyperstoreUserBehavior(SequentialTaskSet):
    wait_time = between(1, 2)  # Delay between 1-2 seconds for each task
    
    def on_start(self):
        """Step 1: Get a valid token for API access"""
        self.read_access_token = fetch_access_token(self, "read")


    @task
    def read_hyper(self):
        """Step 2: Call the GET endpoint 5-12 times."""
        for _ in range(random.randint(5, 12)):
            with self.client.get("/api/hyper", headers={"Authorization": f"Bearer {self.read_access_token}"}, catch_response=True) as response:
                if response.status_code == 401:
                    response.failure(f"Could not read hyper due to authentication - access token: {self.read_access_token}")
                elif response.status_code != 200:
                    response.failure(f"Could not read hyper. Status code: {response.status_code}, Response: {response.text}")
            self.wait()

    @task
    def buy_hyper(self):
        """Step 3: Call the buy endpoint a few times."""
        for _ in range(random.randint(1, 3)):
            with self.client.put("/api/hyper/own", headers={"Authorization": f"Bearer {self.read_access_token}"}, catch_response=True) as response:
                if response.status_code != 200:
                    response.failure("Could not buy hyper")
            self.wait()
    
    @task
    def read_hyper_again(self):
        """Step 4: Read hyper amount again"""
        for _ in range(random.randint(2, 5)):
            with self.client.get("/api/hyper", headers={"Authorization": f"Bearer {self.read_access_token}"}, catch_response=True) as response:
                if response.status_code == 401:
                    response.failure(f"Could not read hyper due to authentication - access token: {self.read_access_token}")
                elif response.status_code != 200:
                    response.failure(f"Could not read hyper again. Status code: {response.status_code}, Response: {response.text}")
            self.wait()

    @task
    def post_endpoint_call_few_times(self):
        """Step 5: Get specific token"""
        self.write_access_token = fetch_access_token(self, "stock")
        """Step 6: Reset stock to 200 hyper"""
        with self.client.post("/api/hyper", headers={"Authorization": f"Bearer {self.write_access_token}"}, json={"quantity": 200}, catch_response=True) as response:
            if response.status_code != 200:
                response.failure("Failed to set quantity to 200")
        self.wait()
        
        # Finish the sequence
        self.interrupt()  # Stop the user after completing the sequence

class HyperstoreUser(HttpUser):
    tasks = [HyperstoreUserBehavior]