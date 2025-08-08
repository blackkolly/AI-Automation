# 🚀 AKAS v2.0 - AI Knowledge Automation System (Enhanced)

Welcome to the **AI Knowledge Automation System v2.0** - a comprehensive, production-ready RAG (Retrieval-Augmented Generation) system for intelligent document processing and querying.

## 🌟 What's New in v2.0

### ✨ Enhanced Features

- **Multi-LLM Support**: OpenAI, Anthropic Claude, Google Gemini
- **Advanced Analytics Dashboard**: Real-time metrics and insights
- **User Feedback System**: Rate responses to improve AI performance
- **Health Monitoring**: Comprehensive system status tracking
- **Multi-file Upload**: Process multiple documents simultaneously
- **Enhanced UI/UX**: Modern, intuitive Streamlit interface

### 🔧 Technical Improvements

- **Graceful Degradation**: Works with subset of API keys
- **Dynamic Provider Detection**: Automatically detects available LLM providers
- **Enhanced Error Handling**: Better resilience and user feedback
- **Production-Ready**: Docker containerization with proper configuration

## 🏗️ System Architecture

### Core Components

- **FastAPI Backend**: RESTful API with LangChain integration
- **Streamlit Frontend**: Multi-page interactive web interface
- **Vector Database**: FAISS for semantic search and retrieval
- **n8n Workflow**: Automation and integration capabilities
- **Docker Compose**: Orchestrated containerized deployment

### Technology Stack

- **Backend**: Python, FastAPI, LangChain, FAISS
- **Frontend**: Streamlit, Plotly for visualizations
- **LLM Integration**: OpenAI, Anthropic, Google APIs
- **Document Processing**: PyPDF2, python-docx, openpyxl
- **Containerization**: Docker, Docker Compose

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- At least one LLM API key (OpenAI recommended)

### 1. Clone and Setup

```bash
cd akas
cp .env.example .env
```

### 2. Configure API Keys

Edit `.env` file with your API keys:

```env
# Required
OPENAI_API_KEY=your_openai_key_here

# Optional (for multi-LLM support)
ANTHROPIC_API_KEY=your_anthropic_key_here
GOOGLE_API_KEY=your_google_key_here

# Optional (for enhanced features)
JWT_SECRET_KEY=your_jwt_secret_here
```

### 3. Launch System

```bash
# Quick launch (Windows)
launch_simple.bat

# Or manually
docker-compose up -d
```

### 4. Access Application

- **Frontend**: http://localhost:8501
- **Backend API**: http://localhost:8000
- **n8n Workflow**: http://localhost:5678

## 📚 User Guide

### Document Upload

1. Navigate to "📄 Document Upload"
2. Select multiple files (PDF, TXT, DOCX, XLSX)
3. Upload and wait for processing
4. Verify successful indexing

### Querying Documents

1. Go to "💬 Query Interface"
2. Select your preferred LLM provider
3. Ask questions about your documents
4. Rate responses to improve performance

### System Monitoring

1. Check "🔍 Health Check" for system status
2. View "📊 Analytics" for usage insights
3. Configure preferences in "⚙️ Settings"

## 🔧 Configuration Options

### Environment Variables

```env
# LLM Provider APIs
OPENAI_API_KEY=sk-...          # Required
ANTHROPIC_API_KEY=sk-...       # Optional
GOOGLE_API_KEY=AIza...         # Optional

# Authentication (Optional)
JWT_SECRET_KEY=your-secret     # For enhanced security

# Backend Configuration
VECTOR_STORE_PATH=./vector_store
LOG_LEVEL=INFO
MAX_FILE_SIZE=10MB
```

### System Settings

- **Default LLM Provider**: Choose preferred AI model
- **Search Parameters**: Similarity vs. MMR search
- **UI Theme**: Light, Dark, or Auto
- **Analytics**: Enable/disable usage tracking

## 🛠️ Advanced Usage

### API Endpoints

```
GET  /v2/health/              # System health status
POST /v2/upload/             # Upload documents
POST /v2/query/              # Query documents
GET  /v2/analytics/          # Usage analytics
POST /v2/feedback/           # Submit feedback
GET  /v2/providers/          # Available LLM providers
```

### Supported File Types

- **PDF**: Documents, reports, research papers
- **TXT**: Plain text files, code, logs
- **DOCX**: Microsoft Word documents
- **XLSX**: Excel spreadsheets, data tables

### Multi-LLM Support

The system automatically detects available LLM providers:

- **OpenAI GPT**: General-purpose, reliable performance
- **Anthropic Claude**: Advanced reasoning, ethical AI
- **Google Gemini**: Multimodal capabilities, fast inference

## 📊 System Monitoring

### Health Indicators

- **Backend Status**: Online/Offline indicator
- **Vector Store**: Document index readiness
- **QA Chain**: Query processing capability
- **LLM Providers**: Available AI models

### Analytics Dashboard

- **Query Volume**: Requests over time
- **Response Quality**: User feedback trends
- **System Performance**: Processing times
- **Provider Usage**: LLM selection patterns

## 🔒 Security Features

### Data Protection

- Local vector storage (no external data transfer)
- Configurable JWT authentication
- Environment-based secret management
- Container isolation for services

### Privacy Considerations

- Documents processed locally
- No data sent to external services (except LLM APIs)
- Optional analytics can be disabled
- User feedback stored locally only

## 🐛 Troubleshooting

### Common Issues

#### Backend Not Starting

```bash
# Check logs
docker-compose logs backend

# Restart services
docker-compose restart backend
```

#### Frontend Connection Issues

1. Verify backend is running on port 8000
2. Check network connectivity between containers
3. Review Docker Compose configuration

#### LLM Provider Errors

1. Verify API keys in `.env` file
2. Check API key permissions and quotas
3. Test with single provider first

#### Document Upload Failures

1. Check file size limits (10MB default)
2. Verify supported file formats
3. Review backend logs for processing errors

### Debugging Tips

- Use Health Check page for system status
- Check container logs: `docker-compose logs [service]`
- Verify environment variables: `docker-compose config`
- Test API endpoints directly at http://localhost:8000/docs

## 🚀 Production Deployment

### Scaling Considerations

- **CPU**: Backend processing can be CPU-intensive
- **Memory**: Vector storage requires sufficient RAM
- **Storage**: Document and vector data persistence
- **Network**: API rate limits for LLM providers

### Recommended Setup

```yaml
# Production docker-compose.override.yml
version: "3.8"
services:
  backend:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G

  frontend:
    deploy:
      resources:
        limits:
          memory: 512M
```

## 📈 Performance Optimization

### Vector Store Optimization

- Regular index cleanup for removed documents
- Batch processing for large document sets
- Appropriate chunk sizes for document splitting

### Query Optimization

- Use specific queries for better results
- Cache frequently accessed documents
- Monitor response times in analytics

## 🤝 Contributing

### Development Setup

```bash
# Install development dependencies
pip install -r requirements-dev.txt

# Run tests
pytest tests/

# Code formatting
black src/
flake8 src/
```

### Adding New Features

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Submit pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

### Getting Help

1. Check this README for common solutions
2. Review system logs and health status
3. Test with minimal configuration first
4. Report issues with detailed error messages

### Community Resources

- **Documentation**: Complete user and developer guides
- **Examples**: Sample configurations and use cases
- **Best Practices**: Performance and security recommendations

---

## 🎯 What Makes AKAS v2.0 Special?

### 🧠 Advanced AI Integration

- **Multi-LLM Support**: Choose the best AI model for your needs
- **Intelligent Fallbacks**: System continues working even with limited API keys
- **Smart Provider Selection**: Automatic optimization based on query type

### 🔍 Sophisticated Document Processing

- **Multi-format Support**: PDF, Word, Excel, and text files
- **Semantic Search**: Find relevant information across large document sets
- **Context-Aware Responses**: Accurate answers with source attribution

### 📊 Enterprise-Ready Features

- **Real-time Analytics**: Track usage patterns and system performance
- **User Feedback Loop**: Continuous improvement through user ratings
- **Health Monitoring**: Proactive system status monitoring
- **Scalable Architecture**: Production-ready containerized deployment

### 🎨 Intuitive User Experience

- **Modern UI**: Clean, responsive Streamlit interface
- **Multi-page Navigation**: Organized workflow for different tasks
- **Real-time Feedback**: Instant status updates and progress indicators
- **Comprehensive Documentation**: Built-in help and guidance

---

**Ready to revolutionize your document workflow? Deploy AKAS v2.0 today!** 🚀
