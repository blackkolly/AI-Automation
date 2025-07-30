# 🤖 Enhanced AKAS v2.0

**Advanced Knowledge Automation System with Security, Analytics & Enhanced UI**

## 🌟 New Features

### 🔐 Security & Authentication
- **JWT-based Authentication**: Secure user sessions with optional mode
- **User Management**: Registration and login system
- **Token-based API Access**: Secure API endpoints with bearer tokens
- **Graceful Degradation**: Works without authentication for development

### 📊 Advanced Analytics
- **Real-time Metrics**: System statistics and performance monitoring
- **Query Analytics**: Response time tracking and query pattern analysis
- **Feedback System**: User rating and comment collection
- **Interactive Charts**: Plotly-powered visualizations

### 🎨 Enhanced UI
- **Multi-page Interface**: Organized navigation with 5 distinct pages
- **Modern Design**: Custom CSS styling with gradient cards
- **Responsive Layout**: Optimized for different screen sizes
- **Interactive Elements**: Expandable sections and dynamic content

### 🔧 Advanced Backend
- **Async Operations**: Non-blocking API operations
- **Enhanced Error Handling**: Comprehensive error responses
- **Health Monitoring**: System health checks and status monitoring
- **Data Persistence**: Optional MongoDB and Redis integration

## 🚀 Quick Start

### 1. Environment Setup
```bash
# Copy environment templates
cp .env.example .env
cp backend/.env.example backend/.env

# Edit .env files with your API keys
# At minimum, add your OpenAI API key
```

### 2. Launch Enhanced AKAS
```bash
# Windows
test_enhanced.bat

# Linux/Mac
chmod +x test_enhanced.sh
./test_enhanced.sh
```

### 3. Access the System
- **Frontend**: http://localhost:8501
- **Backend API**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health

### 4. Login (Optional)
- **Username**: `admin`
- **Password**: `admin123`

## 📋 Interface Pages

### 🏠 Home
- System status overview
- Service health monitoring
- Recent activity summary
- Feature highlights

### 📄 Document Upload
- Drag & drop file upload
- Multiple format support (PDF, TXT, DOC, DOCX, MD)
- Processing status and metrics
- Document library view

### 🔍 Query Interface
- Advanced query form with options
- Real-time response generation
- Source attribution and metadata
- Feedback and rating system
- Session history tracking

### 📊 Analytics
- System performance metrics
- Query processing analytics
- Feedback rating distribution
- Interactive charts and graphs
- Response time tracking

### ⚙️ Settings
- System configuration options
- User preference management
- Admin panel (for admin users)
- Connection testing tools

## 🔧 Configuration

### Required Environment Variables
```env
OPENAI_API_KEY=your_openai_api_key_here
```

### Optional Environment Variables
```env
# Additional AI APIs
ANTHROPIC_API_KEY=your_anthropic_api_key_here
GOOGLE_API_KEY=your_google_api_key_here

# Security
JWT_SECRET_KEY=your_secure_jwt_secret_key_here

# Databases (Optional)
MONGODB_URL=mongodb://admin:password123@mongodb:27017/akas
REDIS_URL=redis://redis:6379
QDRANT_URL=http://qdrant:6333
```

## 🐳 Docker Services

The enhanced version includes multiple optional services:

### Core Services
- **Enhanced Backend**: FastAPI with advanced features
- **Enhanced Frontend**: Multi-page Streamlit interface

### Optional Services
- **MongoDB**: Document and user data persistence
- **Redis**: Query caching and session storage
- **Qdrant**: Advanced vector database for embeddings

## 🔒 Security Features

### Authentication Modes
1. **Full Authentication**: JWT tokens with user management
2. **Optional Authentication**: Works without tokens for development
3. **Admin Features**: Special admin-only endpoints

### API Security
- Bearer token authentication
- Request validation with Pydantic
- Error handling without information leakage
- CORS configuration for cross-origin requests

## 📈 Analytics Features

### System Metrics
- Total documents processed
- Total queries handled
- Average response times
- System uptime tracking

### User Analytics
- Query pattern analysis
- Response time distribution
- Feedback rating analytics
- Session activity tracking

### Visualizations
- Interactive charts with Plotly
- Real-time metric updates
- Historical trend analysis
- Rating distribution graphs

## 🛠️ Development

### Backend Structure
```
backend/
├── enhanced_main.py      # Enhanced FastAPI backend
├── main.py              # Original backend
├── rag_pipeline.py      # RAG processing
├── ingest.py           # Document processing
└── requirements.txt     # Dependencies
```

### Frontend Structure
```
frontend/
├── enhanced_app.py      # Enhanced Streamlit frontend
├── app.py              # Original frontend
└── requirements.txt     # Dependencies
```

### API Endpoints

#### Authentication
- `POST /auth/login` - User login
- `POST /auth/register` - User registration

#### Documents
- `POST /documents/upload` - Upload and process documents
- `GET /documents/list` - List processed documents

#### Queries
- `POST /query` - Process queries with RAG
- `GET /query/history` - Get query history

#### Feedback
- `POST /feedback` - Submit query feedback
- `GET /feedback/analytics` - Get feedback analytics

#### System
- `GET /health` - Health check
- `GET /stats` - System statistics
- `POST /admin/reset` - Reset system data (admin)

## 🔍 Differences from Original

### Enhanced vs Original
| Feature | Original | Enhanced |
|---------|----------|----------|
| Authentication | None | JWT-based optional |
| UI Pages | 1 simple page | 5 specialized pages |
| Analytics | Basic | Advanced with charts |
| Feedback | None | Rating & comment system |
| Security | Basic | JWT tokens & validation |
| Monitoring | None | Health checks & metrics |
| Database | File-based | Optional MongoDB/Redis |
| API Docs | Basic | Comprehensive with models |

## 🚀 Deployment Options

### Development (Current)
```bash
docker-compose -f docker-compose-test-enhanced.yml up --build
```

### Production
1. Configure production environment variables
2. Enable authentication with secure JWT secrets
3. Set up persistent databases (MongoDB, Redis)
4. Configure HTTPS and reverse proxy
5. Enable monitoring and logging

## 📝 Usage Examples

### 1. Document Upload via API
```bash
curl -X POST "http://localhost:8000/documents/upload" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@document.pdf"
```

### 2. Query Processing
```bash
curl -X POST "http://localhost:8000/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "query": "What is the main topic?",
    "max_results": 5,
    "include_metadata": true
  }'
```

### 3. Submit Feedback
```bash
curl -X POST "http://localhost:8000/feedback" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "query": "What is the main topic?",
    "response": "The main topic is...",
    "rating": 5,
    "comment": "Very helpful!"
  }'
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/enhanced-feature`
3. Commit changes: `git commit -am 'Add enhanced feature'`
4. Push branch: `git push origin feature/enhanced-feature`
5. Submit pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For issues and questions:
1. Check the health endpoint: http://localhost:8000/health
2. Review Docker logs: `docker-compose logs`
3. Verify environment configuration
4. Check API documentation: http://localhost:8000/docs

---

**Enhanced AKAS v2.0** - Taking knowledge automation to the next level! 🚀
