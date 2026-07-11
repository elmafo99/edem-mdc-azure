import os
import json
import random
import time
import uuid
from datetime import datetime, timezone

from azure.eventhub import EventHubProducerClient, EventData

EVENTHUB_CONNECTION_STRING = os.environ["EVENTHUB_CONNECTION_STRING"]
EVENTHUB_NAME = os.environ["EVENTHUB_NAME"]
SEND_INTERVAL_SECONDS = float(os.environ.get("SEND_INTERVAL_SECONDS", "2"))

PRODUCTS = [
    {"product_id": 201, "price": 20.00},
    {"product_id": 202, "price": 40.00},
    {"product_id": 203, "price": 15.50},
    {"product_id": 204, "price": 99.90},
    {"product_id": 205, "price": 5.25},
]

PAYMENT_METHODS = ["Credit Card", "Debit Card", "PayPal", "Cash"]


def build_transaction():
    products = random.sample(PRODUCTS, k=random.randint(1, 3))
    line_items = []
    total_amount = 0.0
    for product in products:
        quantity = random.randint(1, 5)
        line_items.append(
            {
                "product_id": product["product_id"],
                "quantity": quantity,
                "price": product["price"],
            }
        )
        total_amount += quantity * product["price"]

    return {
        "transaction_id": f"txn_{uuid.uuid4().hex[:8]}",
        "customer_id": random.randint(1, 100),
        "products": line_items,
        "total_amount": round(total_amount, 2),
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "payment_method": random.choice(PAYMENT_METHODS),
    }


def main():
    producer = EventHubProducerClient.from_connection_string(
        conn_str=EVENTHUB_CONNECTION_STRING,
        eventhub_name=EVENTHUB_NAME,
    )

    print(f"Publicando transacciones en Event Hub '{EVENTHUB_NAME}'...")

    with producer:
        while True:
            transaction = build_transaction()
            batch = producer.create_batch()
            batch.add(EventData(json.dumps(transaction)))
            producer.send_batch(batch)
            print(f"Enviada: {transaction}")
            time.sleep(SEND_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
