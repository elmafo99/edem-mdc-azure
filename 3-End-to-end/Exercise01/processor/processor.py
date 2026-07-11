import os
import json
from datetime import datetime, timezone

from azure.eventhub import EventHubConsumerClient
from pymongo import MongoClient

EVENTHUB_CONNECTION_STRING = os.environ["EVENTHUB_CONNECTION_STRING"]
EVENTHUB_NAME = os.environ["EVENTHUB_NAME"]
EVENTHUB_CONSUMER_GROUP = os.environ.get("EVENTHUB_CONSUMER_GROUP", "$Default")

COSMOSDB_CONNECTION_STRING = os.environ["COSMOSDB_CONNECTION_STRING"]
COSMOSDB_DATABASE_NAME = os.environ.get("COSMOSDB_DATABASE_NAME", "salesdb")
COSMOSDB_COLLECTION_NAME = os.environ.get("COSMOSDB_COLLECTION_NAME", "transactions")

mongo_client = MongoClient(COSMOSDB_CONNECTION_STRING)
collection = mongo_client[COSMOSDB_DATABASE_NAME][COSMOSDB_COLLECTION_NAME]


def transform(transaction):
    transaction["total_items"] = sum(p["quantity"] for p in transaction["products"])
    transaction["payment_method"] = transaction["payment_method"].strip().title()
    transaction["processed_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return transaction


def on_event(partition_context, event):
    raw_transaction = json.loads(event.body_as_str())
    transaction = transform(raw_transaction)

    # Upsert por transaction_id para evitar duplicados si el consumidor se reinicia
    # y vuelve a leer eventos ya procesados.
    collection.update_one(
        {"transaction_id": transaction["transaction_id"]},
        {"$set": transaction},
        upsert=True,
    )

    print(f"Procesada y guardada: {transaction}")


def main():
    consumer = EventHubConsumerClient.from_connection_string(
        conn_str=EVENTHUB_CONNECTION_STRING,
        consumer_group=EVENTHUB_CONSUMER_GROUP,
        eventhub_name=EVENTHUB_NAME,
    )

    print(f"Escuchando eventos de '{EVENTHUB_NAME}'...")

    with consumer:
        consumer.receive(
            on_event=on_event,
            starting_position="-1",  # procesar desde el inicio de lo retenido
        )


if __name__ == "__main__":
    main()
