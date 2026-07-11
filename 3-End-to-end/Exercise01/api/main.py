import os

from fastapi import FastAPI
from pymongo import MongoClient

COSMOSDB_CONNECTION_STRING = os.environ["COSMOSDB_CONNECTION_STRING"]
COSMOSDB_DATABASE_NAME = os.environ.get("COSMOSDB_DATABASE_NAME", "salesdb")
COSMOSDB_COLLECTION_NAME = os.environ.get("COSMOSDB_COLLECTION_NAME", "transactions")

mongo_client = MongoClient(COSMOSDB_CONNECTION_STRING)
collection = mongo_client[COSMOSDB_DATABASE_NAME][COSMOSDB_COLLECTION_NAME]

app = FastAPI(title="Sales Transactions API")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/transactions")
def get_transactions(limit: int = 100):
    docs = list(
        collection.find({}, {"_id": 0}).sort("processed_at", -1).limit(limit)
    )
    return docs


@app.get("/stats/summary")
def get_summary():
    total_transactions = collection.count_documents({})
    total_amount = list(
        collection.aggregate(
            [{"$group": {"_id": None, "total": {"$sum": "$total_amount"}}}]
        )
    )
    return {
        "total_transactions": total_transactions,
        "total_amount": total_amount[0]["total"] if total_amount else 0,
    }


@app.get("/stats/sales-by-payment-method")
def get_sales_by_payment_method():
    pipeline = [
        {
            "$group": {
                "_id": "$payment_method",
                "total_amount": {"$sum": "$total_amount"},
                "transaction_count": {"$sum": 1},
            }
        },
        {"$sort": {"total_amount": -1}},
    ]
    results = list(collection.aggregate(pipeline))
    return [
        {
            "payment_method": r["_id"],
            "total_amount": r["total_amount"],
            "transaction_count": r["transaction_count"],
        }
        for r in results
    ]


@app.get("/stats/sales-by-product")
def get_sales_by_product():
    pipeline = [
        {"$unwind": "$products"},
        {
            "$group": {
                "_id": "$products.product_id",
                "total_quantity": {"$sum": "$products.quantity"},
                "total_amount": {
                    "$sum": {"$multiply": ["$products.quantity", "$products.price"]}
                },
            }
        },
        {"$sort": {"total_amount": -1}},
    ]
    results = list(collection.aggregate(pipeline))
    return [
        {
            "product_id": r["_id"],
            "total_quantity": r["total_quantity"],
            "total_amount": r["total_amount"],
        }
        for r in results
    ]


@app.get("/stats/most-bought-product")
def get_most_bought_product():
    products = get_sales_by_product()
    if not products:
        return None
    return max(products, key=lambda p: p["total_quantity"])
