"""
Enhanced AKAS Frontend with Advanced UI and Analytics
Author: GitHub Copilot
Version: 2.0
"""

import streamlit as st
import requests
import json
import time
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import os

# Page configuration
st.set_page_config(
    page_title="Enhanced AKAS",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Constants
BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8000")
VERSION = "2.0.0"

# Session state initialization
if "authenticated" not in st.session_state:
    st.session_state.authenticated = False
if "auth_token" not in st.session_state:
    st.session_state.auth_token = None
if "username" not in st.session_state:
    st.session_state.username = None
if "query_history" not in st.session_state:
    st.session_state.query_history = []
if "current_page" not in st.session_state:
    st.session_state.current_page = "🏠 Home"

# Custom CSS
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        font-weight: bold;
        color: #1f77b4;
        text-align: center;
        margin-bottom: 1rem;
    }
    .sub-header {
        font-size: 1.5rem;
        color: #666;
        text-align: center;
        margin-bottom: 2rem;
    }
    .metric-card {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        padding: 1rem;
        border-radius: 10px;
        color: white;
        text-align: center;
        margin: 0.5rem;
    }
    .success-message {
        background-color: #d4edda;
        border: 1px solid #c3e6cb;
        color: #155724;
        padding: 0.75rem;
        border-radius: 0.25rem;
        margin: 1rem 0;
    }
    .error-message {
        background-color: #f8d7da;
        border: 1px solid #f5c6cb;
        color: #721c24;
        padding: 0.75rem;
        border-radius: 0.25rem;
        margin: 1rem 0;
    }
    .sidebar-info {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        margin: 1rem 0;
    }
</style>
""", unsafe_allow_html=True)

# Helper functions
def make_request(endpoint: str, method: str = "GET", data: Dict = None, headers: Dict = None) -> Dict:
    """Make HTTP request to backend API"""
    try:
        url = f"{BACKEND_URL}{endpoint}"
        
        if headers is None:
            headers = {}
        
        if st.session_state.auth_token:
            headers["Authorization"] = f"Bearer {st.session_state.auth_token}"
        
        if method == "GET":
            response = requests.get(url, headers=headers, timeout=30)
        elif method == "POST":
            response = requests.post(url, json=data, headers=headers, timeout=30)
        elif method == "PUT":
            response = requests.put(url, json=data, headers=headers, timeout=30)
        elif method == "DELETE":
            response = requests.delete(url, headers=headers, timeout=30)
        
        response.raise_for_status()
        return {"success": True, "data": response.json()}
        
    except requests.exceptions.RequestException as e:
        st.error(f"API Error: {str(e)}")
        return {"success": False, "error": str(e)}
    except json.JSONDecodeError:
        return {"success": False, "error": "Invalid JSON response"}

def authenticate(username: str, password: str) -> bool:
    """Authenticate user"""
    result = make_request("/auth/login", "POST", {
        "username": username,
        "password": password
    })
    
    if result["success"]:
        data = result["data"]
        st.session_state.authenticated = True
        st.session_state.auth_token = data["access_token"]
        st.session_state.username = username
        return True
    return False

def logout():
    """Logout user"""
    st.session_state.authenticated = False
    st.session_state.auth_token = None
    st.session_state.username = None
    st.rerun()

def check_backend_health() -> bool:
    """Check if backend is healthy"""
    try:
        response = requests.get(f"{BACKEND_URL}/health", timeout=5)
        return response.status_code == 200
    except:
        return False

# Sidebar
def render_sidebar():
    """Render sidebar with navigation and status"""
    with st.sidebar:
        st.markdown(f"""
        <div class="sidebar-info">
            <h3>🤖 Enhanced AKAS</h3>
            <p><strong>Version:</strong> {VERSION}</p>
            <p><strong>Status:</strong> {'🟢 Online' if check_backend_health() else '🔴 Offline'}</p>
        </div>
        """, unsafe_allow_html=True)
        
        # Authentication status
        if st.session_state.authenticated:
            st.success(f"👤 Logged in as: {st.session_state.username}")
            if st.button("🚪 Logout", use_container_width=True):
                logout()
        else:
            st.warning("🔒 Not authenticated")
        
        st.markdown("---")
        
        # Navigation
        st.markdown("### 📋 Navigation")
        pages = [
            "🏠 Home",
            "📄 Document Upload",
            "🔍 Query Interface", 
            "📊 Analytics",
            "⚙️ Settings"
        ]
        
        for page in pages:
            if st.button(page, use_container_width=True):
                st.session_state.current_page = page
                st.rerun()
        
        st.markdown("---")
        
        # Quick stats
        if st.session_state.authenticated:
            st.markdown("### 📈 Quick Stats")
            try:
                stats_result = make_request("/stats")
                if stats_result["success"]:
                    stats = stats_result["data"]
                    st.metric("Documents", stats["total_documents"])
                    st.metric("Queries", stats["total_queries"])
                    st.metric("Avg Response", f"{stats['average_response_time']}s")
            except:
                st.error("Failed to load stats")

# Authentication page
def render_auth_page():
    """Render authentication page"""
    st.markdown('<div class="main-header">🔐 Authentication</div>', unsafe_allow_html=True)
    
    tab1, tab2 = st.tabs(["Login", "Register"])
    
    with tab1:
        st.markdown("### 🔑 Login to Enhanced AKAS")
        
        with st.form("login_form"):
            username = st.text_input("Username", placeholder="Enter your username")
            password = st.text_input("Password", type="password", placeholder="Enter your password")
            submit = st.form_submit_button("🚀 Login", use_container_width=True)
            
            if submit:
                if username and password:
                    with st.spinner("Authenticating..."):
                        if authenticate(username, password):
                            st.success("✅ Login successful!")
                            time.sleep(1)
                            st.rerun()
                        else:
                            st.error("❌ Invalid credentials")
                else:
                    st.error("⚠️ Please enter both username and password")
        
        st.info("💡 Demo credentials: username=`admin`, password=`admin123`")
    
    with tab2:
        st.markdown("### 📝 Register New Account")
        
        with st.form("register_form"):
            new_username = st.text_input("Username", placeholder="Choose a username")
            new_email = st.text_input("Email", placeholder="Enter your email")
            new_password = st.text_input("Password", type="password", placeholder="Choose a password")
            confirm_password = st.text_input("Confirm Password", type="password", placeholder="Confirm your password")
            submit_reg = st.form_submit_button("📝 Register", use_container_width=True)
            
            if submit_reg:
                if new_username and new_password and confirm_password:
                    if new_password == confirm_password:
                        result = make_request("/auth/register", "POST", {
                            "username": new_username,
                            "password": new_password,
                            "email": new_email
                        })
                        
                        if result["success"]:
                            st.success("✅ Registration successful! Please login.")
                        else:
                            st.error(f"❌ Registration failed: {result.get('error', 'Unknown error')}")
                    else:
                        st.error("❌ Passwords do not match")
                else:
                    st.error("⚠️ Please fill in all required fields")

# Home page
def render_home_page():
    """Render home page"""
    st.markdown('<div class="main-header">🏠 Enhanced AKAS Dashboard</div>', unsafe_allow_html=True)
    st.markdown('<div class="sub-header">Advanced Knowledge Automation System v2.0</div>', unsafe_allow_html=True)
    
    # Welcome message
    if st.session_state.authenticated:
        st.markdown(f"### Welcome back, {st.session_state.username}! 👋")
    else:
        st.markdown("### Welcome to Enhanced AKAS! 👋")
        st.info("🔒 Please authenticate to access all features.")
    
    # System overview
    col1, col2, col3, col4 = st.columns(4)
    
    try:
        health_result = make_request("/health")
        if health_result["success"]:
            health_data = health_result["data"]
            
            with col1:
                st.markdown("""
                <div class="metric-card">
                    <h3>🟢 System Status</h3>
                    <h2>Online</h2>
                </div>
                """, unsafe_allow_html=True)
            
            with col2:
                st.markdown("""
                <div class="metric-card">
                    <h3>🤖 RAG Pipeline</h3>
                    <h2>{'✅ Ready' if health_data['services']['rag_pipeline'] else '❌ Error'}</h2>
                </div>
                """, unsafe_allow_html=True)
            
            with col3:
                st.markdown("""
                <div class="metric-card">
                    <h3>📄 Doc Processor</h3>
                    <h2>{'✅ Ready' if health_data['services']['document_processor'] else '❌ Error'}</h2>
                </div>
                """, unsafe_allow_html=True)
            
            with col4:
                st.markdown(f"""
                <div class="metric-card">
                    <h3>⏰ Last Update</h3>
                    <h2>{datetime.now().strftime('%H:%M')}</h2>
                </div>
                """, unsafe_allow_html=True)
    except:
        st.error("❌ Unable to connect to backend")
    
    st.markdown("---")
    
    # Features overview
    st.markdown("### 🌟 Enhanced Features")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("""
        #### 🔐 Security & Authentication
        - JWT-based authentication
        - Secure user sessions
        - Optional authentication mode
        
        #### 📄 Document Management
        - Advanced file upload
        - Multiple format support
        - Automatic processing
        """)
    
    with col2:
        st.markdown("""
        #### 🔍 Intelligent Querying
        - Advanced RAG pipeline
        - Context-aware responses
        - Source attribution
        
        #### 📊 Analytics & Insights
        - Real-time metrics
        - Query history
        - Feedback analytics
        """)
    
    # Recent activity
    if st.session_state.authenticated:
        st.markdown("---")
        st.markdown("### 📈 Recent Activity")
        
        try:
            history_result = make_request("/query/history?limit=5")
            if history_result["success"] and history_result["data"]["history"]:
                history_data = history_result["data"]["history"]
                
                for item in history_data:
                    with st.expander(f"Query: {item['query'][:50]}..."):
                        st.write(f"**Response:** {item['response'][:200]}...")
                        st.write(f"**Time:** {item['timestamp']}")
                        st.write(f"**Processing Time:** {item['processing_time']}s")
            else:
                st.info("No recent queries found.")
        except:
            st.error("Failed to load recent activity")

# Document upload page
def render_document_page():
    """Render document upload page"""
    st.markdown('<div class="main-header">📄 Document Upload</div>', unsafe_allow_html=True)
    
    if not st.session_state.authenticated:
        st.warning("🔒 Please authenticate to upload documents.")
        return
    
    st.markdown("### Upload and Process Documents")
    
    uploaded_file = st.file_uploader(
        "Choose a file",
        type=['pdf', 'txt', 'doc', 'docx', 'md'],
        help="Supported formats: PDF, TXT, DOC, DOCX, MD"
    )
    
    if uploaded_file is not None:
        st.info(f"📁 Selected file: {uploaded_file.name} ({uploaded_file.size} bytes)")
        
        if st.button("🚀 Upload and Process", use_container_width=True):
            with st.spinner("Processing document..."):
                try:
                    # Prepare file data
                    files = {"file": (uploaded_file.name, uploaded_file.getvalue(), uploaded_file.type)}
                    headers = {}
                    
                    if st.session_state.auth_token:
                        headers["Authorization"] = f"Bearer {st.session_state.auth_token}"
                    
                    # Upload file
                    response = requests.post(
                        f"{BACKEND_URL}/documents/upload",
                        files=files,
                        headers=headers,
                        timeout=60
                    )
                    
                    if response.status_code == 200:
                        result = response.json()
                        st.success("✅ Document uploaded and processed successfully!")
                        
                        col1, col2, col3 = st.columns(3)
                        with col1:
                            st.metric("Processing Time", f"{result['processing_time']:.2f}s")
                        with col2:
                            st.metric("File Size", f"{result['size']} bytes")
                        with col3:
                            if result.get("chunks_created"):
                                st.metric("Chunks Created", result["chunks_created"])
                    else:
                        st.error(f"❌ Upload failed: {response.text}")
                        
                except Exception as e:
                    st.error(f"❌ Upload error: {str(e)}")
    
    st.markdown("---")
    
    # Document list
    st.markdown("### 📚 Document Library")
    
    try:
        docs_result = make_request("/documents/list")
        if docs_result["success"]:
            docs_data = docs_result["data"]
            st.info(f"Total documents processed: {docs_data['total_count']}")
            
            if docs_data.get("documents"):
                for doc in docs_data["documents"]:
                    with st.expander(doc["filename"]):
                        st.write(f"**Size:** {doc['size']} bytes")
                        st.write(f"**Uploaded:** {doc['timestamp']}")
                        st.write(f"**Chunks:** {doc.get('chunks', 'N/A')}")
            else:
                st.info("📝 Document listing feature coming soon...")
    except:
        st.error("Failed to load document list")

# Query interface page
def render_query_page():
    """Render query interface page"""
    st.markdown('<div class="main-header">🔍 Query Interface</div>', unsafe_allow_html=True)
    
    st.markdown("### Ask Questions About Your Documents")
    
    # Query form
    with st.form("query_form"):
        query = st.text_area(
            "Enter your question:",
            placeholder="What would you like to know?",
            height=100
        )
        
        col1, col2 = st.columns(2)
        with col1:
            max_results = st.slider("Max Results", 1, 20, 5)
        with col2:
            include_metadata = st.checkbox("Include Metadata", value=True)
        
        submit = st.form_submit_button("🔍 Search", use_container_width=True)
        
        if submit and query:
            with st.spinner("Processing query..."):
                start_time = time.time()
                
                result = make_request("/query", "POST", {
                    "query": query,
                    "max_results": max_results,
                    "include_metadata": include_metadata
                })
                
                if result["success"]:
                    response_data = result["data"]
                    processing_time = time.time() - start_time
                    
                    # Store in session history
                    st.session_state.query_history.append({
                        "query": query,
                        "response": response_data["response"],
                        "timestamp": datetime.now().isoformat(),
                        "processing_time": processing_time
                    })
                    
                    st.markdown("### 💬 Response")
                    st.markdown(response_data["response"])
                    
                    # Metrics
                    col1, col2, col3 = st.columns(3)
                    with col1:
                        st.metric("Processing Time", f"{response_data['processing_time']:.2f}s")
                    with col2:
                        st.metric("Sources Found", len(response_data["sources"]))
                    with col3:
                        st.metric("Query Length", len(query))
                    
                    # Sources
                    if response_data["sources"]:
                        st.markdown("### 📚 Sources")
                        for i, source in enumerate(response_data["sources"], 1):
                            with st.expander(f"Source {i}"):
                                st.write(source)
                    
                    # Feedback
                    st.markdown("### 💭 Rate this Response")
                    col1, col2 = st.columns([1, 3])
                    
                    with col1:
                        rating = st.selectbox("Rating", [1, 2, 3, 4, 5], index=4)
                    
                    with col2:
                        comment = st.text_input("Comment (optional)")
                    
                    if st.button("📝 Submit Feedback"):
                        feedback_result = make_request("/feedback", "POST", {
                            "query": query,
                            "response": response_data["response"],
                            "rating": rating,
                            "comment": comment
                        })
                        
                        if feedback_result["success"]:
                            st.success("✅ Feedback submitted!")
                        else:
                            st.error("❌ Failed to submit feedback")
                
                else:
                    st.error(f"❌ Query failed: {result.get('error', 'Unknown error')}")
    
    # Query history
    if st.session_state.query_history:
        st.markdown("---")
        st.markdown("### 📜 Session History")
        
        for i, item in enumerate(reversed(st.session_state.query_history[-5:]), 1):
            with st.expander(f"Query {i}: {item['query'][:50]}..."):
                st.write(f"**Query:** {item['query']}")
                st.write(f"**Response:** {item['response'][:300]}...")
                st.write(f"**Time:** {item['timestamp']}")

# Analytics page
def render_analytics_page():
    """Render analytics page"""
    st.markdown('<div class="main-header">📊 Analytics Dashboard</div>', unsafe_allow_html=True)
    
    if not st.session_state.authenticated:
        st.warning("🔒 Please authenticate to view analytics.")
        return
    
    # System statistics
    try:
        stats_result = make_request("/stats")
        if stats_result["success"]:
            stats = stats_result["data"]
            
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                st.metric("📄 Total Documents", stats["total_documents"])
            with col2:
                st.metric("🔍 Total Queries", stats["total_queries"])
            with col3:
                st.metric("⚡ Avg Response Time", f"{stats['average_response_time']:.2f}s")
            with col4:
                st.metric("⏰ System Uptime", stats["uptime"])
    except:
        st.error("Failed to load system statistics")
    
    st.markdown("---")
    
    # Feedback analytics
    try:
        feedback_result = make_request("/feedback/analytics")
        if feedback_result["success"]:
            feedback_data = feedback_result["data"]
            
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown("### 📝 Feedback Overview")
                st.metric("Total Feedback", feedback_data["total_feedback"])
                st.metric("Average Rating", f"{feedback_data['average_rating']}/5")
            
            with col2:
                st.markdown("### ⭐ Rating Distribution")
                if feedback_data["rating_distribution"]:
                    rating_df = pd.DataFrame([
                        {"Rating": f"{k} Stars", "Count": v}
                        for k, v in feedback_data["rating_distribution"].items()
                    ])
                    
                    fig = px.bar(rating_df, x="Rating", y="Count", 
                               title="Rating Distribution")
                    st.plotly_chart(fig, use_container_width=True)
    except:
        st.error("Failed to load feedback analytics")
    
    st.markdown("---")
    
    # Query history analytics
    if st.session_state.query_history:
        st.markdown("### 📈 Session Query Analytics")
        
        # Response time chart
        query_df = pd.DataFrame(st.session_state.query_history)
        query_df['timestamp'] = pd.to_datetime(query_df['timestamp'])
        
        fig = px.line(query_df, x='timestamp', y='processing_time',
                     title='Query Processing Time Over Session')
        st.plotly_chart(fig, use_container_width=True)
        
        # Query length distribution
        query_df['query_length'] = query_df['query'].str.len()
        fig2 = px.histogram(query_df, x='query_length',
                           title='Query Length Distribution')
        st.plotly_chart(fig2, use_container_width=True)

# Settings page
def render_settings_page():
    """Render settings page"""
    st.markdown('<div class="main-header">⚙️ Settings</div>', unsafe_allow_html=True)
    
    # System settings
    st.markdown("### 🔧 System Configuration")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("#### 🌐 Backend Configuration")
        new_backend_url = st.text_input("Backend URL", value=BACKEND_URL)
        
        if st.button("🔄 Test Connection"):
            try:
                response = requests.get(f"{new_backend_url}/health", timeout=5)
                if response.status_code == 200:
                    st.success("✅ Connection successful!")
                else:
                    st.error("❌ Connection failed")
            except:
                st.error("❌ Unable to connect")
    
    with col2:
        st.markdown("#### 🎨 UI Preferences")
        theme = st.selectbox("Theme", ["Light", "Dark", "Auto"])
        language = st.selectbox("Language", ["English", "Spanish", "French"])
        items_per_page = st.slider("Items per page", 5, 50, 10)
    
    st.markdown("---")
    
    # User settings
    if st.session_state.authenticated:
        st.markdown("### 👤 User Settings")
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("#### 🔐 Account")
            st.info(f"Username: {st.session_state.username}")
            
            if st.button("🔑 Change Password"):
                st.info("Password change feature coming soon...")
        
        with col2:
            st.markdown("#### 📊 Preferences")
            auto_save = st.checkbox("Auto-save queries", value=True)
            email_notifications = st.checkbox("Email notifications", value=False)
            advanced_mode = st.checkbox("Advanced mode", value=False)
    
    st.markdown("---")
    
    # Admin settings
    if st.session_state.authenticated and st.session_state.username == "admin":
        st.markdown("### 🔐 Admin Panel")
        st.warning("⚠️ Admin functions - use with caution!")
        
        col1, col2 = st.columns(2)
        
        with col1:
            if st.button("🗑️ Reset System Data", type="secondary"):
                if st.confirm("Are you sure you want to reset all system data?"):
                    result = make_request("/admin/reset", "POST")
                    if result["success"]:
                        st.success("✅ System data reset successfully!")
                        st.session_state.query_history.clear()
                    else:
                        st.error("❌ Failed to reset system data")
        
        with col2:
            if st.button("📊 Export Analytics", type="secondary"):
                st.info("Export feature coming soon...")
    
    st.markdown("---")
    
    # About
    st.markdown("### ℹ️ About Enhanced AKAS")
    st.markdown(f"""
    - **Version:** {VERSION}
    - **Backend URL:** {BACKEND_URL}
    - **Authentication:** {'Enabled' if st.session_state.authenticated else 'Disabled'}
    - **Build Date:** {datetime.now().strftime('%Y-%m-%d')}
    """)

# Main application
def main():
    """Main application function"""
    render_sidebar()
    
    # Route to appropriate page
    if not st.session_state.authenticated and st.session_state.current_page not in ["🏠 Home"]:
        render_auth_page()
    else:
        if st.session_state.current_page == "🏠 Home":
            render_home_page()
        elif st.session_state.current_page == "📄 Document Upload":
            render_document_page()
        elif st.session_state.current_page == "🔍 Query Interface":
            render_query_page()
        elif st.session_state.current_page == "📊 Analytics":
            render_analytics_page()
        elif st.session_state.current_page == "⚙️ Settings":
            render_settings_page()
        else:
            render_home_page()

if __name__ == "__main__":
    main()
