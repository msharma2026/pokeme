from google.cloud import datastore
import os

# Initialize Datastore client
# When running on App Engine, credentials are automatic
client = datastore.Client()


def get_client():
    return client


def Entity(key):
    """Create a Datastore entity."""
    return datastore.Entity(key=key)
