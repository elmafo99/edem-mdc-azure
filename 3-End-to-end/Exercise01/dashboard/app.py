import os

import pandas as pd
import requests
import streamlit as st

API_BASE_URL = os.environ["API_BASE_URL"].rstrip("/")

st.set_page_config(page_title="Sales Dashboard", layout="wide")
st.title("📊 Sales Dashboard")


@st.cache_data(ttl=10)
def fetch(path: str):
    response = requests.get(f"{API_BASE_URL}{path}", timeout=10)
    response.raise_for_status()
    return response.json()


summary = fetch("/stats/summary")
col1, col2 = st.columns(2)
col1.metric("Total transacciones", summary["total_transactions"])
col2.metric("Importe total vendido", f"${summary['total_amount']:,.2f}")

most_bought = fetch("/stats/most-bought-product")
if most_bought:
    st.metric(
        "Producto más vendido (por unidades)",
        f"Producto {most_bought['product_id']}",
        f"{most_bought['total_quantity']} unidades",
    )

st.divider()

col1, col2 = st.columns(2)

with col1:
    st.subheader("Ventas por método de pago")
    by_payment = pd.DataFrame(fetch("/stats/sales-by-payment-method"))
    if not by_payment.empty:
        st.bar_chart(by_payment.set_index("payment_method")["total_amount"])

with col2:
    st.subheader("Importe vendido por producto")
    by_product = pd.DataFrame(fetch("/stats/sales-by-product"))
    if not by_product.empty:
        by_product["product_id"] = by_product["product_id"].astype(str)
        st.bar_chart(by_product.set_index("product_id")["total_amount"])

st.divider()

st.subheader("Últimas transacciones")
transactions = pd.DataFrame(fetch("/transactions?limit=50"))
st.dataframe(transactions, use_container_width=True)
