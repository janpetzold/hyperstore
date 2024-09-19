from locust import HttpUser, task, between

class SimpleUser(HttpUser):
    @task
    def load_test(self):
        self.client.get("/api/hyper") # Fetch data

    wait_time = between(0.05, 2)  # Wait time between requests