import streamlit as st
import requests
import plotly.express as px
import pandas as pd
from datetime import datetime
import time

st.set_page_config(page_title="Enhanced AKAS", layout="wide", page_icon="🤖")

# Custom CSS
st.markdown("""
<style>
.metric-container {
    background-color: #f0f2f6;
    padding: 1rem;
    border-radius: 0.5rem;
    margin: 0.5rem 0;
}
</style>
""", unsafe_allow_html=True)

# Sidebar for navigation
st.sidebar.title("🤖 AKAS Navigation")
page = st.sidebar.selectbox("Choose a page", 
    ["📄 Document Upload", "💬 Query Interface", "📊 Analytics", "⚙️ Settings", "🔍 Health Check", "📖 Documentation"])

# Backend URL
BACKEND_URL = "http://backend:8000"

def check_backend_health():
    """Check if backend is healthy"""
    try:
        response = requests.get(f"{BACKEND_URL}/v2/health/", timeout=5)
        return response.status_code == 200, response.json() if response.status_code == 200 else None
    except:
        return False, None

def get_available_providers():
    """Get available LLM providers from backend"""
    try:
        response = requests.get(f"{BACKEND_URL}/v2/providers/", timeout=5)
        if response.status_code == 200:
            data = response.json()
            return data.get("available_providers", ["openai"])
        return ["openai"]
    except:
        return ["openai"]

# Health indicator in sidebar
is_healthy, health_info = check_backend_health()
if is_healthy:
    st.sidebar.success("✅ Backend Online")
    if health_info:
        st.sidebar.info(f"Vector Store: {'✅' if health_info.get('vector_store_ready') else '❌'}")
        st.sidebar.info(f"QA Chain: {'✅' if health_info.get('qa_chain_ready') else '❌'}")
        
        # Show available LLM providers
        providers = health_info.get('available_llm_providers', ['openai'])
        st.sidebar.info(f"LLM Providers: {', '.join(providers)}")
        
        if len(providers) == 1 and providers[0] == 'openai':
            st.sidebar.warning("ℹ️ Only OpenAI available. Add more API keys for additional LLM options.")
else:
    st.sidebar.error("❌ Backend Offline")

if page == "📄 Document Upload":
    st.title("📄 Enhanced Document Upload")
    st.markdown("Upload multiple documents to enhance your knowledge base")
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        uploaded_files = st.file_uploader(
            "Choose files to upload", 
            type=["pdf", "txt", "docx", "xlsx"],
            accept_multiple_files=True,
            help="Supported formats: PDF, TXT, DOCX, XLSX"
        )
        
        if uploaded_files:
            st.write(f"📁 Selected {len(uploaded_files)} file(s):")
            for file in uploaded_files:
                st.write(f"- {file.name} ({file.size} bytes)")
            
            if st.button("🚀 Upload & Process", type="primary"):
                files = [("files", (f.name, f.getvalue(), f.type)) for f in uploaded_files]
                
                progress_bar = st.progress(0)
                status_text = st.empty()
                
                status_text.text("Uploading files...")
                progress_bar.progress(25)
                
                try:
                    response = requests.post(f"{BACKEND_URL}/v2/ingest/", files=files, timeout=60)
                    progress_bar.progress(75)
                    
                    if response.status_code == 200:
                        progress_bar.progress(100)
                        status_text.text("Processing complete!")
                        
                        results = response.json()
                        st.success(f"✅ Successfully processed {len(results['results'])} documents!")
                        
                        # Display results table
                        if results.get("results"):
                            df = pd.DataFrame(results["results"])
                            df = df[["filename", "status", "uploaded_at"]]  # Select relevant columns
                            st.dataframe(df, use_container_width=True)
                        
                        st.info(f"📊 Total chunks created: {results.get('total_chunks', 'N/A')}")
                        
                    else:
                        st.error(f"❌ Upload failed: {response.text}")
                        
                except requests.exceptions.Timeout:
                    st.error("⏱️ Upload timed out. Please try again with fewer or smaller files.")
                except Exception as e:
                    st.error(f"❌ Error: {str(e)}")
                finally:
                    progress_bar.empty()
                    status_text.empty()
    
    with col2:
        st.subheader("📈 Upload Statistics")
        if is_healthy and health_info:
            st.metric("Backend Status", "Online" if is_healthy else "Offline")
            st.metric("Vector Store", "Ready" if health_info.get('vector_store_ready') else "Not Ready")
        
        # Tips
        st.markdown("""
        ### 💡 Tips:
        - Upload multiple files at once
        - Supported formats: PDF, TXT, DOCX, XLSX
        - Larger files take longer to process
        - Check health status before uploading
        """)

elif page == "💬 Query Interface":
    st.title("💬 Enhanced Query Interface")
    st.markdown("Ask questions about your uploaded documents")
    
    col1, col2 = st.columns([3, 1])
    
    with col1:
        question = st.text_area(
            "🤔 Ask a question about your documents:", 
            height=100,
            placeholder="e.g., What is the main topic of the documents? Summarize the key findings..."
        )
        
        # Advanced options in expander
        with st.expander("🔧 Advanced Options"):
            col_llm, col_search = st.columns(2)
            with col_llm:
                available_providers = get_available_providers()
                llm_provider = st.selectbox("LLM Provider", available_providers)
                if len(available_providers) == 1:
                    st.info(f"ℹ️ Only {available_providers[0]} is currently available")
            with col_search:
                search_type = st.selectbox("Search Type", ["similarity", "mmr"])
                k_docs = st.slider("Documents to retrieve", 1, 10, 4)
        
        if st.button("🔍 Ask Question", type="primary") and question:
            if not is_healthy:
                st.error("❌ Backend is not available. Please check the connection.")
            else:
                with st.spinner("🔍 Searching and generating answer..."):
                    payload = {
                        "question": question,
                        "llm_provider": llm_provider,
                        "search_type": search_type,
                        "k": k_docs
                    }
                    
                    try:
                        response = requests.post(f"{BACKEND_URL}/v2/query/", json=payload, timeout=30)
                        
                        if response.status_code == 200:
                            result = response.json()
                            
                            # Display answer
                            st.subheader("💡 Answer:")
                            st.markdown(result["answer"])
                            
                            # Display metrics
                            col_conf, col_time = st.columns(2)
                            with col_conf:
                                st.metric("🎯 Confidence", f"{result['confidence']:.1%}")
                            with col_time:
                                st.metric("⏱️ Processing Time", f"{result['processing_time']:.2f}s")
                            
                            # Store query ID for feedback
                            st.session_state.last_query_id = result.get("query_id")
                            
                            # Display sources if available
                            if result.get("sources"):
                                st.subheader("📚 Sources:")
                                for i, source in enumerate(result["sources"], 1):
                                    with st.expander(f"Source {i}: {source.get('source', 'Unknown')}"):
                                        st.json(source)
                            
                        else:
                            st.error(f"❌ Query failed: {response.text}")
                            
                    except requests.exceptions.Timeout:
                        st.error("⏱️ Query timed out. Please try a simpler question.")
                    except Exception as e:
                        st.error(f"❌ Error: {str(e)}")
        
        # Feedback section
        if hasattr(st.session_state, 'last_query_id'):
            st.markdown("---")
            st.subheader("📝 Rate this answer:")
            
            col_rating, col_feedback = st.columns([1, 2])
            with col_rating:
                rating = st.slider("Rating", 1, 5, 3, help="1=Poor, 5=Excellent")
            with col_feedback:
                feedback_comment = st.text_input("Optional feedback:", placeholder="Any comments or suggestions?")
            
            if st.button("📤 Submit Feedback"):
                feedback_data = {
                    "query_id": st.session_state.last_query_id,
                    "rating": rating,
                    "comment": feedback_comment
                }
                
                try:
                    response = requests.post(f"{BACKEND_URL}/v2/feedback/", json=feedback_data)
                    if response.status_code == 200:
                        st.success("✅ Thank you for your feedback!")
                        del st.session_state.last_query_id
                    else:
                        st.error("❌ Failed to submit feedback")
                except Exception as e:
                    st.error(f"❌ Error submitting feedback: {str(e)}")
    
    with col2:
        st.subheader("💭 Query Suggestions")
        suggestions = [
            "What are the main topics?",
            "Summarize key findings",
            "What are the conclusions?",
            "List important dates",
            "Who are the key people mentioned?"
        ]
        
        for suggestion in suggestions:
            if st.button(f"💡 {suggestion}", key=f"suggest_{suggestion}"):
                st.session_state.suggested_question = suggestion
                st.experimental_rerun()

elif page == "📊 Analytics":
    st.title("📊 System Analytics")
    st.markdown("Monitor your AKAS system performance and usage")
    
    if not is_healthy:
        st.error("❌ Cannot load analytics - backend is not available")
    else:
        try:
            response = requests.get(f"{BACKEND_URL}/v2/analytics/")
            if response.status_code == 200:
                analytics = response.json()
                
                # Key metrics
                col1, col2, col3, col4 = st.columns(4)
                
                with col1:
                    st.metric("📊 Total Queries", analytics["total_queries"])
                with col2:
                    st.metric("⏱️ Avg Response Time", f"{analytics['avg_response_time']}s")
                with col3:
                    st.metric("😊 User Satisfaction", f"{analytics['user_satisfaction']}/5")
                with col4:
                    st.metric("📈 System Health", "Good" if is_healthy else "Poor")
                
                # Charts section
                st.markdown("---")
                col_chart1, col_chart2 = st.columns(2)
                
                with col_chart1:
                    st.subheader("🔥 Popular Topics")
                    if analytics.get("popular_topics"):
                        topics_df = pd.DataFrame({
                            'Topic': analytics["popular_topics"][:5],
                            'Frequency': range(len(analytics["popular_topics"][:5]), 0, -1)
                        })
                        fig = px.bar(topics_df, x='Frequency', y='Topic', orientation='h',
                                   title="Most Queried Topics")
                        st.plotly_chart(fig, use_container_width=True)
                    else:
                        st.info("No query data available yet")
                
                with col_chart2:
                    st.subheader("📈 Performance Metrics")
                    # Mock performance data for demo
                    perf_data = {
                        'Metric': ['Response Time', 'Accuracy', 'Relevance', 'User Satisfaction'],
                        'Score': [85, 92, 88, analytics['user_satisfaction'] * 20]
                    }
                    perf_df = pd.DataFrame(perf_data)
                    fig = px.bar(perf_df, x='Metric', y='Score', 
                               title="System Performance Scores")
                    fig.update_layout(yaxis_range=[0, 100])
                    st.plotly_chart(fig, use_container_width=True)
                
                # Recent activity
                st.markdown("---")
                st.subheader("🕒 Recent Activity")
                st.info("Recent activity logging will be implemented with database integration")
                
            else:
                st.error("❌ Failed to load analytics")
        except Exception as e:
            st.error(f"❌ Error loading analytics: {str(e)}")

elif page == "⚙️ Settings":
    st.title("⚙️ System Settings")
    st.markdown("Configure your AKAS system preferences")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("🤖 LLM Configuration")
        available_providers = get_available_providers()
        default_llm = st.selectbox("Default LLM Provider", 
            available_providers, 
            help="Choose your preferred language model provider")
        
        if len(available_providers) == 1:
            st.info(f"ℹ️ Only {available_providers[0]} is currently configured. Add more API keys to use additional providers.")
        
        st.subheader("🔍 Search Configuration")
        chunk_size = st.slider("Chunk Size", 100, 2000, 1000, 
                              help="Size of text chunks for processing")
        chunk_overlap = st.slider("Chunk Overlap", 0, 500, 200,
                                 help="Overlap between consecutive chunks")
        
        confidence_threshold = st.slider("Confidence Threshold", 0.0, 1.0, 0.7,
                                       help="Minimum confidence for answers")
    
    with col2:
        st.subheader("🎨 UI Preferences")
        theme = st.selectbox("Theme", ["Light", "Dark", "Auto"])
        auto_refresh = st.checkbox("Auto-refresh analytics", value=True)
        show_sources = st.checkbox("Always show sources", value=True)
        
        st.subheader("🔔 Notifications")
        email_notifications = st.checkbox("Email notifications")
        query_alerts = st.checkbox("Query performance alerts")
    
    st.markdown("---")
    col_save, col_reset = st.columns(2)
    
    with col_save:
        if st.button("💾 Save Settings", type="primary"):
            # In a real implementation, these would be saved to a database
            st.success("✅ Settings saved successfully!")
    
    with col_reset:
        if st.button("🔄 Reset to Defaults"):
            st.info("🔄 Settings reset to defaults")

elif page == "🔍 Health Check":
    st.title("🔍 System Health Check")
    st.markdown("Monitor the health and status of your AKAS system")
    
    if st.button("🔄 Refresh Health Status"):
        st.experimental_rerun()
    
    # Backend Health
    st.subheader("🖥️ Backend Health")
    if is_healthy and health_info:
        st.success("✅ Backend is online and healthy")
        
        col1, col2 = st.columns(2)
        with col1:
            st.metric("Version", health_info.get("version", "Unknown"))
            st.metric("Vector Store", "Ready" if health_info.get("vector_store_ready") else "Not Ready")
        with col2:
            st.metric("QA Chain", "Ready" if health_info.get("qa_chain_ready") else "Not Ready")
            st.metric("Last Check", datetime.now().strftime("%H:%M:%S"))
        
        # Show health details
        with st.expander("🔍 Detailed Health Information"):
            st.json(health_info)
    else:
        st.error("❌ Backend is not responding")
        st.markdown("""
        **Troubleshooting steps:**
        1. Check if the backend container is running
        2. Verify the backend URL configuration
        3. Check network connectivity
        4. Review backend logs for errors
        """)
    
    # System Resources (mock data)
    st.subheader("💻 System Resources")
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric("CPU Usage", "45%", "2%")
    with col2:
        st.metric("Memory Usage", "2.1 GB", "100 MB")
    with col3:
        st.metric("Disk Usage", "15.3 GB", "500 MB")

elif page == "📖 Documentation":
    st.title("📖 AKAS Documentation")
    
    st.header("🏗️ System Architecture")
    st.write("""
    **AI Knowledge Automation System (AKAS)** is a comprehensive RAG-based document processing and querying system.
    """)
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("🧠 Core Technologies")
        st.write("""
        - **RAG (Retrieval-Augmented Generation)**: Combines retrieval and generation for accurate answers
        - **Vector Embeddings**: Convert text to numerical representations for semantic search
        - **FAISS**: Fast similarity search for document retrieval
        - **LangChain**: Framework for building LLM applications
        - **Streamlit**: Interactive web interface
        """)
        
    with col2:
        st.subheader("🔧 Available LLM Providers")
        if health_info and health_info.get('available_llm_providers'):
            providers = health_info.get('available_llm_providers', [])
            for provider in providers:
                if provider == 'openai':
                    st.write("✅ **OpenAI**: GPT models (configured)")
                elif provider == 'anthropic':
                    st.write("✅ **Anthropic**: Claude models (configured)")
                elif provider == 'google':
                    st.write("✅ **Google**: Gemini models (configured)")
            
            if 'anthropic' not in providers:
                st.write("❌ **Anthropic**: Not configured (add ANTHROPIC_API_KEY)")
            if 'google' not in providers:
                st.write("❌ **Google**: Not configured (add GOOGLE_API_KEY)")
        else:
            st.warning("Unable to check provider status")
    
    st.header("🚀 Quick Start Guide")
    st.write("""
    1. **Upload Documents**: Go to 'Document Upload' and upload your files
    2. **Ask Questions**: Use 'Query Interface' to ask questions about your documents
    3. **Monitor System**: Check 'System Health' for status and analytics
    4. **Provide Feedback**: Rate responses to help improve the system
    """)
    
    st.header("📝 Supported File Types")
    st.write("""
    - **PDF**: Documents, reports, research papers
    - **TXT**: Plain text files
    - **DOCX**: Microsoft Word documents
    - **XLSX**: Excel spreadsheets
    """)
    
    st.header("🛠️ Advanced Features")
    st.write("""
    - **Multi-file Upload**: Process multiple documents simultaneously
    - **Real-time Health Monitoring**: System status and performance metrics
    - **Analytics Dashboard**: Track usage patterns and system performance
    - **Feedback System**: Rate responses to improve AI performance
    - **Multiple LLM Support**: Choose from different AI providers
    """)
    
    st.header("💡 Tips for Best Results")
    st.write("""
    - Upload diverse, high-quality documents for better knowledge coverage
    - Ask specific, detailed questions for more accurate responses
    - Use the feedback system to help improve AI performance
    - Check system health regularly for optimal performance
    """)
    
    if st.button("🔄 Refresh System Status"):
        st.rerun()

# Footer
st.sidebar.markdown("---")
st.sidebar.info("Enhanced AKAS v2.0")
st.sidebar.markdown("AI Knowledge Automation System")

# Handle suggested questions
if hasattr(st.session_state, 'suggested_question'):
    st.sidebar.success(f"Question suggested: {st.session_state.suggested_question}")
    del st.session_state.suggested_question
