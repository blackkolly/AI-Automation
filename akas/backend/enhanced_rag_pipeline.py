from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain_community.vectorstores import FAISS
from langchain.chains import RetrievalQA
from langchain_community.llms import OpenAI
from langchain_anthropic import ChatAnthropic
import os

class EnhancedRAGPipeline:
    def __init__(self, llm_provider="openai"):
        self.llm_provider = llm_provider
        self.embeddings = OpenAIEmbeddings()
        
    def get_llm(self):
        """Get LLM based on provider selection"""
        if self.llm_provider == "openai":
            return ChatOpenAI(temperature=0, model="gpt-3.5-turbo")
        elif self.llm_provider == "anthropic":
            return ChatAnthropic(temperature=0, model="claude-3-sonnet-20240229")
        else:
            return OpenAI(temperature=0)
    
    def build_vector_store(self, docs):
        """Enhanced vector store with persistence"""
        vector_store = FAISS.from_documents(docs, self.embeddings)
        # Save for persistence
        vector_store.save_local("./vector_store")
        return vector_store
    
    def load_vector_store(self):
        """Load existing vector store"""
        try:
            return FAISS.load_local("./vector_store", self.embeddings)
        except:
            return None
    
    def get_qa_chain(self, vector_store, search_type="similarity", k=4):
        """Enhanced QA chain with configurable retrieval"""
        retriever = vector_store.as_retriever(
            search_type=search_type,
            search_kwargs={"k": k}
        )
        llm = self.get_llm()
        return RetrievalQA.from_chain_type(
            llm, 
            retriever=retriever,
            return_source_documents=True  # Return sources for provenance
        )
