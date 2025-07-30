"""
Enhanced AKAS Backend with Security and Advanced Features
Author: GitHub Copilot
Version: 2.0
"""

import os
import logging
import asyncio
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, Form, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import uvicorn
import jwt
from passlib.context import CryptContext

# Import existing AKAS modules
from main import app as main_app
from rag_pipeline import RAGPipeline
from ingest import DocumentProcessor

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Security configuration
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "fallback-secret-key-for-development")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer(auto_error=False)

# Pydantic models
class UserLogin(BaseModel):
    username: str
    password: str

class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6)
    email: Optional[str] = None

class QueryRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=1000)
    max_results: Optional[int] = Field(default=5, ge=1, le=20)
    include_metadata: Optional[bool] = False

class QueryResponse(BaseModel):
    query: str
    response: str
    sources: List[Dict[str, Any]]
    processing_time: float
    timestamp: str

class DocumentUploadResponse(BaseModel):
    filename: str
    size: int
    status: str
    processing_time: float
    chunks_created: Optional[int] = None

class FeedbackRequest(BaseModel):
    query: str
    response: str
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None

class SystemStats(BaseModel):
    total_documents: int
    total_queries: int
    average_response_time: float
    uptime: str

# Global variables
rag_pipeline = None
doc_processor = None
query_history = []
feedback_data = []
system_stats = {
    "total_documents": 0,
    "total_queries": 0,
    "total_response_time": 0.0,
    "startup_time": datetime.now()
}

# Authentication functions
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create JWT access token"""
    try:
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=15)
        to_encode.update({"exp": expire})
        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return encoded_jwt
    except Exception as e:
        logger.error(f"Token creation failed: {e}")
        return None

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify JWT token - optional authentication"""
    if not credentials:
        return None
    
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            return None
        return username
    except jwt.PyJWTError:
        return None

# Lifespan management
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize and cleanup application resources"""
    global rag_pipeline, doc_processor
    
    logger.info("🚀 Starting Enhanced AKAS Backend...")
    
    try:
        # Initialize RAG pipeline
        rag_pipeline = RAGPipeline()
        await asyncio.to_thread(rag_pipeline.initialize)
        
        # Initialize document processor
        doc_processor = DocumentProcessor()
        
        logger.info("✅ Enhanced AKAS Backend initialized successfully")
        
        yield
        
    except Exception as e:
        logger.error(f"❌ Failed to initialize Enhanced AKAS: {e}")
        yield
    finally:
        logger.info("🔄 Shutting down Enhanced AKAS Backend...")

# Create FastAPI app
app = FastAPI(
    title="Enhanced AKAS API",
    description="Advanced Knowledge Automation System with Security & Analytics",
    version="2.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Authentication endpoints
@app.post("/auth/login")
async def login(user_data: UserLogin):
    """Authenticate user and return JWT token"""
    # Simplified authentication - in production, verify against database
    if user_data.username == "admin" and user_data.password == "admin123":
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": user_data.username}, expires_delta=access_token_expires
        )
        
        if access_token:
            return {
                "access_token": access_token,
                "token_type": "bearer",
                "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60
            }
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Incorrect username or password"
    )

@app.post("/auth/register")
async def register(user_data: UserCreate):
    """Register new user"""
    # Simplified registration - in production, save to database
    logger.info(f"Registration attempt for user: {user_data.username}")
    
    # Check if user already exists (simplified)
    if user_data.username == "admin":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already exists"
        )
    
    return {
        "message": "User registered successfully",
        "username": user_data.username
    }

# Document management endpoints
@app.post("/documents/upload", response_model=DocumentUploadResponse)
async def upload_document(
    file: UploadFile = File(...),
    current_user: Optional[str] = Depends(verify_token)
):
    """Upload and process a document"""
    start_time = datetime.now()
    
    try:
        if not file.filename:
            raise HTTPException(status_code=400, detail="No file provided")
        
        # Save uploaded file
        file_path = f"/tmp/{file.filename}"
        content = await file.read()
        
        with open(file_path, "wb") as f:
            f.write(content)
        
        # Process document
        if doc_processor:
            chunks = await asyncio.to_thread(doc_processor.process_document, file_path)
            system_stats["total_documents"] += 1
        else:
            chunks = 0
        
        processing_time = (datetime.now() - start_time).total_seconds()
        
        # Clean up
        os.remove(file_path)
        
        return DocumentUploadResponse(
            filename=file.filename,
            size=len(content),
            status="processed",
            processing_time=processing_time,
            chunks_created=chunks
        )
        
    except Exception as e:
        logger.error(f"Document upload failed: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

@app.get("/documents/list")
async def list_documents(current_user: Optional[str] = Depends(verify_token)):
    """List all processed documents"""
    try:
        # In a real implementation, this would query the vector database
        return {
            "documents": [],
            "total_count": system_stats["total_documents"],
            "message": "Document listing feature coming soon"
        }
    except Exception as e:
        logger.error(f"Document listing failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to list documents")

# Query endpoints
@app.post("/query", response_model=QueryResponse)
async def process_query(
    request: QueryRequest,
    current_user: Optional[str] = Depends(verify_token)
):
    """Process a query using RAG pipeline"""
    start_time = datetime.now()
    
    try:
        if not rag_pipeline:
            raise HTTPException(status_code=503, detail="RAG pipeline not initialized")
        
        # Process query
        result = await asyncio.to_thread(
            rag_pipeline.query,
            request.query,
            max_results=request.max_results
        )
        
        processing_time = (datetime.now() - start_time).total_seconds()
        
        # Update statistics
        system_stats["total_queries"] += 1
        system_stats["total_response_time"] += processing_time
        
        # Store query history
        query_record = {
            "query": request.query,
            "response": result.get("response", ""),
            "timestamp": datetime.now().isoformat(),
            "processing_time": processing_time,
            "user": current_user
        }
        query_history.append(query_record)
        
        # Keep only last 100 queries
        if len(query_history) > 100:
            query_history.pop(0)
        
        return QueryResponse(
            query=request.query,
            response=result.get("response", "No response generated"),
            sources=result.get("sources", []),
            processing_time=processing_time,
            timestamp=datetime.now().isoformat()
        )
        
    except Exception as e:
        logger.error(f"Query processing failed: {e}")
        raise HTTPException(status_code=500, detail=f"Query failed: {str(e)}")

@app.get("/query/history")
async def get_query_history(
    limit: int = 10,
    current_user: Optional[str] = Depends(verify_token)
):
    """Get query history"""
    try:
        # Filter by user if authenticated
        filtered_history = query_history
        if current_user:
            filtered_history = [q for q in query_history if q.get("user") == current_user]
        
        return {
            "history": filtered_history[-limit:],
            "total_queries": len(filtered_history)
        }
    except Exception as e:
        logger.error(f"History retrieval failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve history")

# Feedback endpoints
@app.post("/feedback")
async def submit_feedback(
    feedback: FeedbackRequest,
    current_user: Optional[str] = Depends(verify_token)
):
    """Submit feedback for a query response"""
    try:
        feedback_record = {
            "query": feedback.query,
            "response": feedback.response,
            "rating": feedback.rating,
            "comment": feedback.comment,
            "timestamp": datetime.now().isoformat(),
            "user": current_user
        }
        
        feedback_data.append(feedback_record)
        
        # Keep only last 1000 feedback records
        if len(feedback_data) > 1000:
            feedback_data.pop(0)
        
        return {"message": "Feedback submitted successfully"}
        
    except Exception as e:
        logger.error(f"Feedback submission failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to submit feedback")

@app.get("/feedback/analytics")
async def get_feedback_analytics(current_user: Optional[str] = Depends(verify_token)):
    """Get feedback analytics"""
    try:
        if not feedback_data:
            return {
                "total_feedback": 0,
                "average_rating": 0,
                "rating_distribution": {}
            }
        
        total_feedback = len(feedback_data)
        average_rating = sum(f["rating"] for f in feedback_data) / total_feedback
        
        rating_distribution = {}
        for i in range(1, 6):
            rating_distribution[str(i)] = len([f for f in feedback_data if f["rating"] == i])
        
        return {
            "total_feedback": total_feedback,
            "average_rating": round(average_rating, 2),
            "rating_distribution": rating_distribution
        }
        
    except Exception as e:
        logger.error(f"Analytics retrieval failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve analytics")

# System endpoints
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "services": {
            "rag_pipeline": rag_pipeline is not None,
            "document_processor": doc_processor is not None
        }
    }

@app.get("/stats", response_model=SystemStats)
async def get_system_stats(current_user: Optional[str] = Depends(verify_token)):
    """Get system statistics"""
    try:
        uptime = datetime.now() - system_stats["startup_time"]
        average_response_time = 0
        
        if system_stats["total_queries"] > 0:
            average_response_time = system_stats["total_response_time"] / system_stats["total_queries"]
        
        return SystemStats(
            total_documents=system_stats["total_documents"],
            total_queries=system_stats["total_queries"],
            average_response_time=round(average_response_time, 3),
            uptime=str(uptime)
        )
        
    except Exception as e:
        logger.error(f"Stats retrieval failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve stats")

# Admin endpoints
@app.post("/admin/reset")
async def reset_system(current_user: Optional[str] = Depends(verify_token)):
    """Reset system data (admin only)"""
    try:
        # In production, verify admin role
        if current_user != "admin":
            raise HTTPException(status_code=403, detail="Admin access required")
        
        global query_history, feedback_data, system_stats
        
        query_history.clear()
        feedback_data.clear()
        system_stats.update({
            "total_documents": 0,
            "total_queries": 0,
            "total_response_time": 0.0,
            "startup_time": datetime.now()
        })
        
        return {"message": "System data reset successfully"}
        
    except Exception as e:
        logger.error(f"System reset failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to reset system")

# Include original main app routes
app.mount("/v1", main_app)

if __name__ == "__main__":
    uvicorn.run(
        "enhanced_main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
