from fastapi import FastAPI, UploadFile, File
from ingest import ingest_documents
from rag_pipeline import build_vector_store, get_qa_chain
from mcp import process_task

app = FastAPI()
vector_store = None
qa_chain = None

@app.post("/ingest/")
async def ingest(file: UploadFile = File(...)):
    with open(f"docs/{file.filename}", "wb") as f:
        f.write(await file.read())
    docs = ingest_documents("docs")
    global vector_store, qa_chain
    vector_store = build_vector_store(docs)
    qa_chain = get_qa_chain(vector_store)
    return {"status": "ingested", "file": file.filename}

@app.post("/query/")
async def query(q: str):
    if not qa_chain:
        return {"error": "No data ingested yet."}
    answer = qa_chain.run(q)
    return {"answer": answer}

@app.post("/mcp/")
async def mcp(task: dict):
    return process_task(task)
