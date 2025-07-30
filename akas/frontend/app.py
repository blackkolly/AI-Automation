import streamlit as st
import requests

st.title("AKAS: AI Knowledge Automation System")

st.header("Document Ingestion")
st.header("Ask a Question")
uploaded_file = st.file_uploader("Upload a PDF document", type=["pdf"])
if uploaded_file:
    files = {"file": (uploaded_file.name, uploaded_file, "application/pdf")}
    resp = requests.post("http://backend:8000/ingest/", files=files)
    st.write(f"Status code: {resp.status_code}")
    st.write(f"Response text: {resp.text}")
    try:
        st.write(resp.json())
    except Exception as e:
        st.error(f"Could not parse JSON: {e}")

st.header("Ask a Question")
query = st.text_input("Enter your question:")
if st.button("Ask") and query:
    resp = requests.post("http://backend:8000/query/", params={"q": query})
    st.write(resp.json())
