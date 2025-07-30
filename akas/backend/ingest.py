import os
from langchain_community.document_loaders import PyPDFLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter

def ingest_documents(doc_dir):
    docs = []
    for fname in os.listdir(doc_dir):
        if fname.endswith(".pdf"):
            loader = PyPDFLoader(os.path.join(doc_dir, fname))
            docs.extend(loader.load())
    splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
    return splitter.split_documents(docs)
