# AKAS: AI Knowledge Automation System

## Overview
AKAS is an AI-powered knowledge automation system with document ingestion, semantic search, RAG pipeline, n8n workflow orchestration, and a Streamlit UI.

## Structure
- `backend/`: FastAPI, LangChain, FAISS, OpenAI integration
- `frontend/`: Streamlit UI
- `n8n/`: Workflow automation
- `docs/`: Place your documents here

## Quickstart
1. Add your OpenAI API key to `backend/.env`
2. Place documents in `docs/`
3. Run `docker-compose up --build` from the `akas/` directory
4. Access:
   - Backend API: http://localhost:8000
   - Frontend UI: http://localhost:8501
   - n8n: http://localhost:5678 (user: admin, pass: admin)
