from fastapi import FastAPI, UploadFile, File, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
import time
import uuid
from datetime import datetime
from typing import List, Optional

# Import your existing modules
from ingest import ingest_documents
from rag_pipeline import build_vector_store, get_qa_chain
from mcp import process_task

app = FastAPI(title="Enhanced AKAS API", version="2.0.0")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables (replace with proper database in production)
vector_store = None
qa_chain = None
query_logs = []
feedback_data = []

# Models
class QueryRequest(BaseModel):
    question: str
    llm_provider: Optional[str] = "openai"  # Default to OpenAI since we have that key
    search_type: Optional[str] = "similarity"
    k: Optional[int] = 4

class QueryResponse(BaseModel):
    answer: str
    sources: List[dict] = []
    confidence: float = 0.85
    processing_time: float
    query_id: str

class UserFeedback(BaseModel):
    query_id: str
    rating: int  # 1-5
    comment: Optional[str] = None

class AnalyticsResponse(BaseModel):
    total_queries: int
    avg_response_time: float
    popular_topics: List[str]
    user_satisfaction: float

# Check available LLM providers
def get_available_llm_providers():
    """Check which LLM providers are available based on API keys"""
    providers = []
    
    if os.getenv("OPENAI_API_KEY"):
        providers.append("openai")
    if os.getenv("ANTHROPIC_API_KEY"):
        providers.append("anthropic")
    if os.getenv("GOOGLE_API_KEY"):
        providers.append("google")
    
    return providers if providers else ["openai"]  # Default to OpenAI

# Enhanced endpoints
@app.post("/v2/ingest/")
async def enhanced_ingest(files: List[UploadFile] = File(...)):
    """Enhanced ingestion with metadata tracking"""
    global vector_store, qa_chain
    results = []
    
    for file in files:
        file_id = str(uuid.uuid4())
        
        # Ensure docs directory exists
        os.makedirs("docs", exist_ok=True)
        
        # Save file with unique name
        file_path = f"docs/{file_id}_{file.filename}"
        with open(file_path, "wb") as f:
            content = await file.read()
            f.write(content)
        
        results.append({
            "file_id": file_id,
            "filename": file.filename,
            "status": "saved",
            "file_path": file_path,
            "uploaded_at": datetime.now().isoformat()
        })
    
    # Process all documents
    try:
        docs = ingest_documents("docs")
        
        # Update vector store
        if docs:
            vector_store = build_vector_store(docs)
            qa_chain = get_qa_chain(vector_store)
            
            # Update results with processing info
            for result in results:
                result["status"] = "processed"
                result["chunks_created"] = len(docs) // len(results)  # Approximate
        
        return {"results": results, "total_chunks": len(docs)}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Processing error: {str(e)}")

@app.post("/v2/query/", response_model=QueryResponse)
async def enhanced_query(request: QueryRequest):
    """Enhanced query with source tracking and analytics"""
    global qa_chain, query_logs
    
    start_time = time.time()
    query_id = str(uuid.uuid4())
    
    if not qa_chain:
        raise HTTPException(status_code=400, detail="No data ingested yet. Please upload documents first.")
    
    try:
        # Execute query using existing qa_chain
        result = qa_chain.run(request.question)
        
        processing_time = time.time() - start_time
        
        # Log query for analytics
        query_log = {
            "query_id": query_id,
            "question": request.question,
            "answer": result,
            "llm_provider": request.llm_provider,
            "processing_time": processing_time,
            "timestamp": datetime.now().isoformat()
        }
        query_logs.append(query_log)
        
        # Keep only last 100 queries in memory
        if len(query_logs) > 100:
            query_logs = query_logs[-100:]
        
        return QueryResponse(
            answer=result,
            sources=[],  # Will be enhanced when we add source tracking
            confidence=0.85,
            processing_time=processing_time,
            query_id=query_id
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query error: {str(e)}")

@app.post("/v2/feedback/")
async def submit_feedback(feedback: UserFeedback):
    """Collect user feedback for improving the system"""
    global feedback_data
    
    feedback_entry = {
        "feedback_id": str(uuid.uuid4()),
        "query_id": feedback.query_id,
        "rating": feedback.rating,
        "comment": feedback.comment,
        "timestamp": datetime.now().isoformat()
    }
    
    feedback_data.append(feedback_entry)
    
    # Keep only last 100 feedback entries in memory
    if len(feedback_data) > 100:
        feedback_data = feedback_data[-100:]
    
    return {"status": "feedback_received", "feedback_id": feedback_entry["feedback_id"]}

@app.get("/v2/analytics/", response_model=AnalyticsResponse)
async def get_analytics():
    """Get usage analytics and insights"""
    global query_logs, feedback_data
    
    total_queries = len(query_logs)
    avg_response_time = sum(log["processing_time"] for log in query_logs) / max(total_queries, 1)
    
    # Extract popular topics (simple keyword extraction)
    all_questions = " ".join(log["question"] for log in query_logs)
    words = all_questions.lower().split()
    word_freq = {}
    for word in words:
        if len(word) > 3:  # Only consider words longer than 3 characters
            word_freq[word] = word_freq.get(word, 0) + 1
    
    popular_topics = sorted(word_freq.items(), key=lambda x: x[1], reverse=True)[:5]
    popular_topics = [topic[0] for topic in popular_topics]
    
    # Calculate user satisfaction
    if feedback_data:
        avg_rating = sum(f["rating"] for f in feedback_data) / len(feedback_data)
    else:
        avg_rating = 4.0  # Default
    
    return AnalyticsResponse(
        total_queries=total_queries,
        avg_response_time=round(avg_response_time, 2),
        popular_topics=popular_topics,
        user_satisfaction=round(avg_rating, 1)
    )

@app.get("/v2/health/")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": "2.0.0",
        "vector_store_ready": vector_store is not None,
        "qa_chain_ready": qa_chain is not None,
        "available_llm_providers": get_available_llm_providers(),
        "timestamp": datetime.now().isoformat()
    }

@app.get("/v2/providers/")
async def get_llm_providers():
    """Get available LLM providers"""
    return {
        "available_providers": get_available_llm_providers(),
        "default_provider": "openai"
    }

# Keep existing v1 endpoints for backward compatibility
@app.post("/ingest/")
async def ingest(file: UploadFile = File(...)):
    """Original ingest endpoint for backward compatibility"""
    files = [file]
    result = await enhanced_ingest(files)
    return {"status": "ingested", "file": file.filename, "details": result}

@app.post("/query/")
async def query(q: str = Query(...)):
    """Original query endpoint for backward compatibility"""
    request = QueryRequest(question=q)
    result = await enhanced_query(request)
    return {"answer": result.answer}

@app.post("/mcp/")
async def mcp(task: dict):
    """MCP endpoint"""
    return process_task(task)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
