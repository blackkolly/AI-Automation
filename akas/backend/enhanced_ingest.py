import os
from datetime import datetime
from langchain_community.document_loaders import (
    PyPDFLoader, 
    TextLoader, 
    UnstructuredWordDocumentLoader,
    UnstructuredExcelLoader,
    WebBaseLoader
)
from langchain.text_splitter import RecursiveCharacterTextSplitter

class EnhancedDocumentIngestor:
    def __init__(self):
        self.splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000, 
            chunk_overlap=200
        )
    
    def ingest_documents(self, doc_dir):
        """Enhanced document ingestion supporting multiple formats"""
        docs = []
        
        for fname in os.listdir(doc_dir):
            file_path = os.path.join(doc_dir, fname)
            
            try:
                if fname.lower().endswith('.pdf'):
                    loader = PyPDFLoader(file_path)
                elif fname.lower().endswith('.txt'):
                    loader = TextLoader(file_path)
                elif fname.lower().endswith('.docx'):
                    loader = UnstructuredWordDocumentLoader(file_path)
                elif fname.lower().endswith('.xlsx'):
                    loader = UnstructuredExcelLoader(file_path)
                else:
                    continue  # Skip unsupported files
                
                documents = loader.load()
                docs.extend(documents)
                
            except Exception as e:
                print(f"Error loading {fname}: {e}")
                continue
        
        # Split documents
        split_docs = self.splitter.split_documents(docs)
        
        # Add metadata
        for doc in split_docs:
            doc.metadata['processed_at'] = str(datetime.now())
            doc.metadata['file_type'] = os.path.splitext(doc.metadata.get('source', ''))[-1]
        
        return split_docs
    
    def ingest_web_content(self, urls):
        """Ingest content from web URLs"""
        docs = []
        for url in urls:
            try:
                loader = WebBaseLoader(url)
                web_docs = loader.load()
                docs.extend(web_docs)
            except Exception as e:
                print(f"Error loading {url}: {e}")
        
        return self.splitter.split_documents(docs)
