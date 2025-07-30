from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores import FAISS
from langchain.chains import RetrievalQA
from langchain_community.llms import OpenAI

def build_vector_store(docs):
    embeddings = OpenAIEmbeddings()
    return FAISS.from_documents(docs, embeddings)

def get_qa_chain(vector_store):
    retriever = vector_store.as_retriever()
    llm = OpenAI(temperature=0)
    return RetrievalQA.from_chain_type(llm, retriever=retriever)
