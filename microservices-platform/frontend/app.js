// Configuration
const API_BASE_URL = 'http://localhost:3001/api';
const WS_BASE_URL = 'ws://localhost:3001';

// State Management
class AppState {
  constructor() {
    this.user = null;
    this.token = localStorage.getItem('token');
    this.cart = JSON.parse(localStorage.getItem('cart') || '[]');
    this.products = [];
    this.orders = [];
    this.currentView = 'home';
  }

  setUser(user) {
    this.user = user;
    this.notifyStateChange();
  }

  setToken(token) {
    this.token = token;
    if (token) {
      localStorage.setItem('token', token);
    } else {
      localStorage.removeItem('token');
    }
  }

  addToCart(product, quantity = 1) {
    const existingItem = this.cart.find(item => item.id === product.id);
    if (existingItem) {
      existingItem.quantity += quantity;
    } else {
      this.cart.push({ ...product, quantity });
    }
    this.saveCart();
    this.updateCartUI();
  }

  removeFromCart(productId) {
    this.cart = this.cart.filter(item => item.id !== productId);
    this.saveCart();
    this.updateCartUI();
  }

  saveCart() {
    localStorage.setItem('cart', JSON.stringify(this.cart));
  }

  updateCartUI() {
    const cartCount = this.cart.reduce((sum, item) => sum + item.quantity, 0);
    document.getElementById('cartCount').textContent = cartCount;
    
    const cartTotal = this.cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    document.getElementById('cartTotal').textContent = cartTotal.toFixed(2);
    
    this.renderCartItems();
  }

  renderCartItems() {
    const cartItemsContainer = document.getElementById('cartItems');
    
    if (this.cart.length === 0) {
      cartItemsContainer.innerHTML = '<p class="empty-cart">Your cart is empty</p>';
      return;
    }

    cartItemsContainer.innerHTML = this.cart.map(item => `
      <div class="cart-item">
        <div class="cart-item-info">
          <h4>${item.name}</h4>
          <p>Quantity: ${item.quantity}</p>
        </div>
        <div class="cart-item-price">$${(item.price * item.quantity).toFixed(2)}</div>
        <button onclick="appState.removeFromCart(${item.id})" class="btn btn-danger" style="padding: 4px 8px; font-size: 12px;">Remove</button>
      </div>
    `).join('');
  }

  notifyStateChange() {
    // Update UI based on authentication state
    this.updateAuthUI();
  }

  updateAuthUI() {
    const loginBtn = document.getElementById('loginBtn');
    const registerBtn = document.getElementById('registerBtn');
    const userMenu = document.getElementById('userMenu');
    const userName = document.getElementById('userName');
    const addProductBtn = document.getElementById('addProductBtn');
    const ordersSection = document.getElementById('orders');

    if (this.user) {
      loginBtn.style.display = 'none';
      registerBtn.style.display = 'none';
      userMenu.style.display = 'flex';
      userName.textContent = this.user.name || this.user.email;
      addProductBtn.style.display = 'inline-flex';
      
      // Show orders link in navigation
      const ordersLink = document.querySelector('a[href="#orders"]');
      if (ordersLink) {
        ordersLink.style.display = 'inline';
      }
    } else {
      loginBtn.style.display = 'inline-flex';
      registerBtn.style.display = 'inline-flex';
      userMenu.style.display = 'none';
      addProductBtn.style.display = 'none';
      
      // Hide orders link in navigation
      const ordersLink = document.querySelector('a[href="#orders"]');
      if (ordersLink) {
        ordersLink.style.display = 'none';
      }
    }
  }
}

// Initialize app state
const appState = new AppState();

// API Service
class ApiService {
  static async request(endpoint, options = {}) {
    const url = `${API_BASE_URL}${endpoint}`;
    const config = {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      },
      ...options
    };

    if (appState.token) {
      config.headers['Authorization'] = `Bearer ${appState.token}`;
    }

    try {
      const response = await fetch(url, config);
      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || 'Request failed');
      }

      return data;
    } catch (error) {
      console.error('API Request failed:', error);
      throw error;
    }
  }

  // Auth endpoints
  static async login(email, password) {
    return this.request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password })
    });
  }

  static async register(name, email, password) {
    return this.request('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ name, email, password })
    });
  }

  static async getProfile() {
    return this.request('/auth/me');
  }

  // Product endpoints
  static async getProducts(search = '', category = '') {
    const params = new URLSearchParams();
    if (search) params.append('search', search);
    if (category) params.append('category', category);
    
    return this.request(`/products?${params.toString()}`);
  }

  static async createProduct(product) {
    return this.request('/products', {
      method: 'POST',
      body: JSON.stringify(product)
    });
  }

  static async updateProduct(id, product) {
    return this.request(`/products/${id}`, {
      method: 'PUT',
      body: JSON.stringify(product)
    });
  }

  static async deleteProduct(id) {
    return this.request(`/products/${id}`, {
      method: 'DELETE'
    });
  }

  // Order endpoints
  static async getOrders() {
    return this.request('/orders');
  }

  static async createOrder(items) {
    return this.request('/orders', {
      method: 'POST',
      body: JSON.stringify({ items })
    });
  }

  static async getOrderById(id) {
    return this.request(`/orders/${id}`);
  }
}

// WebSocket Service for real-time updates
class WebSocketService {
  constructor() {
    this.ws = null;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
  }

  connect() {
    try {
      this.ws = new WebSocket(`${WS_BASE_URL}/ws`);
      
      this.ws.onopen = () => {
        console.log('WebSocket connected');
        this.reconnectAttempts = 0;
        showToast('Connected to real-time updates', 'success');
      };

      this.ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          this.handleMessage(data);
        } catch (error) {
          console.error('Failed to parse WebSocket message:', error);
        }
      };

      this.ws.onclose = () => {
        console.log('WebSocket disconnected');
        this.attemptReconnect();
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
      };
    } catch (error) {
      console.error('Failed to connect WebSocket:', error);
    }
  }

  handleMessage(data) {
    switch (data.type) {
      case 'ORDER_STATUS_UPDATE':
        showToast(`Order ${data.orderId} status updated to ${data.status}`, 'info');
        if (appState.currentView === 'orders') {
          loadOrders();
        }
        break;
      case 'PRODUCT_UPDATE':
        showToast('Product inventory updated', 'info');
        if (appState.currentView === 'products') {
          loadProducts();
        }
        break;
      default:
        console.log('Unknown WebSocket message type:', data.type);
    }
  }

  attemptReconnect() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      const delay = Math.pow(2, this.reconnectAttempts) * 1000;
      console.log(`Attempting to reconnect in ${delay}ms...`);
      setTimeout(() => this.connect(), delay);
    }
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

// Initialize WebSocket
const wsService = new WebSocketService();

// Utility Functions
function showToast(message, type = 'success') {
  const toastContainer = document.getElementById('toastContainer');
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `
    <div style="display: flex; align-items: center; gap: 8px;">
      <i class="fas fa-${type === 'success' ? 'check-circle' : type === 'error' ? 'exclamation-circle' : 'info-circle'}"></i>
      <span>${message}</span>
    </div>
  `;
  
  toastContainer.appendChild(toast);
  
  setTimeout(() => {
    toast.remove();
  }, 5000);
}

function getProductImage(product) {
  // If product has an image URL, use it
  if (product.imageUrl) {
    return product.imageUrl;
  }
  
  // Otherwise, return a category-specific placeholder image
  const categoryImages = {
    'electronics': 'https://images.unsplash.com/photo-1498049794561-7780e7231661?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
    'clothing': 'https://images.unsplash.com/photo-1445205170230-053b83016050?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
    'food': 'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
    'books': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
    'home': 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
    'sports': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
    'beauty': 'https://images.unsplash.com/photo-1596462502278-27bfdc403348?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
    'automotive': 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80'
  };
  
  return categoryImages[product.category.toLowerCase()] || 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80';
}

function getCategoryIcon(category) {
  const categoryIcons = {
    'electronics': 'fas fa-laptop',
    'clothing': 'fas fa-tshirt',
    'food': 'fas fa-utensils',
    'books': 'fas fa-book',
    'home': 'fas fa-home',
    'sports': 'fas fa-dumbbell',
    'beauty': 'fas fa-heart',
    'automotive': 'fas fa-car'
  };
  
  return categoryIcons[category.toLowerCase()] || 'fas fa-box';
}

function showLoading(show = true) {
  const overlay = document.getElementById('loadingOverlay');
  overlay.style.display = show ? 'flex' : 'none';
}

function formatDate(dateString) {
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}

// Authentication Functions
async function handleLogin(event) {
  event.preventDefault();
  
  const email = document.getElementById('loginEmail').value;
  const password = document.getElementById('loginPassword').value;
  
  try {
    showLoading(true);
    const response = await ApiService.login(email, password);
    
    appState.setToken(response.token);
    appState.setUser(response.user);
    
    closeModal('loginModal');
    showToast('Login successful!');
    
    // Load user-specific data
    loadOrders();
  } catch (error) {
    showToast(error.message, 'error');
  } finally {
    showLoading(false);
  }
}

async function handleRegister(event) {
  event.preventDefault();
  
  const name = document.getElementById('registerName').value;
  const email = document.getElementById('registerEmail').value;
  const password = document.getElementById('registerPassword').value;
  const confirmPassword = document.getElementById('registerConfirmPassword').value;
  
  if (password !== confirmPassword) {
    showToast('Passwords do not match', 'error');
    return;
  }
  
  try {
    showLoading(true);
    const response = await ApiService.register(name, email, password);
    
    appState.setToken(response.token);
    appState.setUser(response.user);
    
    closeModal('registerModal');
    showToast('Registration successful!');
  } catch (error) {
    showToast(error.message, 'error');
  } finally {
    showLoading(false);
  }
}

function handleLogout() {
  appState.setToken(null);
  appState.setUser(null);
  appState.cart = [];
  appState.saveCart();
  appState.updateCartUI();
  
  showToast('Logged out successfully');
  showView('home');
}

// Product Functions
async function loadProducts() {
  const searchTerm = document.getElementById('searchInput').value;
  const category = document.getElementById('categoryFilter').value;
  const productsGrid = document.getElementById('productsGrid');
  const productsLoading = document.getElementById('productsLoading');
  
  try {
    productsLoading.style.display = 'flex';
    productsGrid.style.display = 'none';
    
    const response = await ApiService.getProducts(searchTerm, category);
    appState.products = response.products || response;
    
    renderProducts(appState.products);
  } catch (error) {
    showToast('Failed to load products', 'error');
    productsGrid.innerHTML = '<p class="error">Failed to load products</p>';
  } finally {
    productsLoading.style.display = 'none';
    productsGrid.style.display = 'grid';
  }
}

function renderProducts(products) {
  const productsGrid = document.getElementById('productsGrid');
  
  if (products.length === 0) {
    productsGrid.innerHTML = '<p class="no-products">No products found</p>';
    return;
  }
  
  productsGrid.innerHTML = products.map(product => {
    const imageUrl = getProductImage(product);
    const categoryIcon = getCategoryIcon(product.category);
    
    return `
      <div class="product-card" onclick="viewProduct(${product.id})">
        <div class="product-image">
          <img src="${imageUrl}" alt="${product.name}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';">
          <div class="placeholder-icon" style="display: none;">
            <i class="${categoryIcon}"></i>
          </div>
          <div class="category-badge">${product.category}</div>
        </div>
        <div class="product-info">
          <h3 class="product-title">${product.name}</h3>
          <p class="product-description">${product.description || 'No description available'}</p>
          <div class="product-meta">
            <span class="product-price">$${product.price}</span>
            <span class="product-stock ${product.stock > 0 ? (product.stock > 10 ? 'in-stock' : 'low-stock') : 'out-of-stock'}">
              ${product.stock > 0 ? `${product.stock} in stock` : 'Out of stock'}
            </span>
          </div>
          <div class="product-actions">
            <button onclick="event.stopPropagation(); addToCart(${product.id})" 
                    class="btn btn-primary" 
                    ${product.stock === 0 ? 'disabled' : ''}>
              <i class="fas fa-cart-plus"></i>
              ${product.stock === 0 ? 'Out of Stock' : 'Add to Cart'}
            </button>
            ${appState.user ? `
              <button onclick="event.stopPropagation(); editProduct(${product.id})" 
                      class="btn btn-outline" 
                      title="Edit Product">
                <i class="fas fa-edit"></i>
              </button>
              <button onclick="event.stopPropagation(); deleteProduct(${product.id})" 
                      class="btn btn-danger" 
                      title="Delete Product">
                <i class="fas fa-trash"></i>
              </button>
            ` : ''}
          </div>
        </div>
      </div>
    `;
  }).join('');
}

function addToCart(productId) {
  const product = appState.products.find(p => p.id === productId);
  if (product && product.stock > 0) {
    appState.addToCart(product);
    showToast(`${product.name} added to cart`);
  } else {
    showToast('Product out of stock', 'error');
  }
}

async function handleProductForm(event) {
  event.preventDefault();
  
  const formData = {
    name: document.getElementById('productName').value,
    description: document.getElementById('productDescription').value,
    price: parseFloat(document.getElementById('productPrice').value),
    category: document.getElementById('productCategory').value,
    stock: parseInt(document.getElementById('productStock').value)
  };
  
  try {
    showLoading(true);
    
    const productId = document.getElementById('productForm').dataset.productId;
    if (productId) {
      await ApiService.updateProduct(productId, formData);
      showToast('Product updated successfully');
    } else {
      await ApiService.createProduct(formData);
      showToast('Product created successfully');
    }
    
    closeModal('productModal');
    loadProducts();
  } catch (error) {
    showToast(error.message, 'error');
  } finally {
    showLoading(false);
  }
}

function showAddProductModal() {
  document.getElementById('productModalTitle').textContent = 'Add Product';
  document.getElementById('productForm').reset();
  delete document.getElementById('productForm').dataset.productId;
  openModal('productModal');
}

function editProduct(productId) {
  const product = appState.products.find(p => p.id === productId);
  if (!product) return;
  
  document.getElementById('productModalTitle').textContent = 'Edit Product';
  document.getElementById('productName').value = product.name;
  document.getElementById('productDescription').value = product.description || '';
  document.getElementById('productPrice').value = product.price;
  document.getElementById('productCategory').value = product.category;
  document.getElementById('productStock').value = product.stock;
  document.getElementById('productForm').dataset.productId = productId;
  
  openModal('productModal');
}

async function deleteProduct(productId) {
  if (!confirm('Are you sure you want to delete this product?')) return;
  
  try {
    showLoading(true);
    await ApiService.deleteProduct(productId);
    showToast('Product deleted successfully');
    loadProducts();
  } catch (error) {
    showToast(error.message, 'error');
  } finally {
    showLoading(false);
  }
}

// Order Functions
async function loadOrders() {
  if (!appState.user) return;
  
  const ordersContainer = document.getElementById('ordersContainer');
  const ordersLoading = document.getElementById('ordersLoading');
  
  try {
    ordersLoading.style.display = 'flex';
    ordersContainer.style.display = 'none';
    
    const response = await ApiService.getOrders();
    appState.orders = response.orders || response;
    
    renderOrders(appState.orders);
  } catch (error) {
    showToast('Failed to load orders', 'error');
    ordersContainer.innerHTML = '<p class="error">Failed to load orders</p>';
  } finally {
    ordersLoading.style.display = 'none';
    ordersContainer.style.display = 'block';
  }
}

function renderOrders(orders) {
  const ordersContainer = document.getElementById('ordersContainer');
  
  if (orders.length === 0) {
    ordersContainer.innerHTML = '<p class="no-orders">No orders found</p>';
    return;
  }
  
  ordersContainer.innerHTML = orders.map(order => `
    <div class="order-card">
      <div class="order-header">
        <div class="order-info">
          <h3>Order #${order.id}</h3>
          <p>Placed on ${formatDate(order.createdAt)}</p>
        </div>
        <span class="order-status status-${order.status}">${order.status}</span>
      </div>
      <div class="order-items">
        ${order.items.map(item => `
          <div class="order-item">
            <span>${item.productName} × ${item.quantity}</span>
            <span>$${(item.price * item.quantity).toFixed(2)}</span>
          </div>
        `).join('')}
      </div>
      <div class="order-total">
        Total: $${order.total.toFixed(2)}
      </div>
    </div>
  `).join('');
}

async function checkout() {
  if (!appState.user) {
    showToast('Please login to checkout', 'error');
    openModal('loginModal');
    return;
  }
  
  if (appState.cart.length === 0) {
    showToast('Your cart is empty', 'error');
    return;
  }
  
  try {
    showLoading(true);
    
    const orderItems = appState.cart.map(item => ({
      productId: item.id,
      quantity: item.quantity,
      price: item.price
    }));
    
    const response = await ApiService.createOrder(orderItems);
    
    appState.cart = [];
    appState.saveCart();
    appState.updateCartUI();
    
    closeCart();
    showToast('Order placed successfully!');
    showView('orders');
    loadOrders();
  } catch (error) {
    showToast(error.message, 'error');
  } finally {
    showLoading(false);
  }
}

// UI Functions
function openModal(modalId) {
  document.getElementById(modalId).style.display = 'block';
}

function closeModal(modalId) {
  document.getElementById(modalId).style.display = 'none';
}

function openCart() {
  document.getElementById('cartSidebar').classList.add('open');
}

function closeCart() {
  document.getElementById('cartSidebar').classList.remove('open');
}

function showView(viewName) {
  appState.currentView = viewName;
  
  // Hide all sections
  document.querySelectorAll('main section').forEach(section => {
    section.style.display = 'none';
  });
  
  // Show target section
  const targetSection = document.getElementById(viewName);
  if (targetSection) {
    targetSection.style.display = 'block';
  }
  
  // Load data for the view
  switch (viewName) {
    case 'products':
      loadProducts();
      break;
    case 'orders':
      if (appState.user) {
        loadOrders();
      } else {
        showToast('Please login to view orders', 'error');
        showView('home');
      }
      break;
  }
}

// Event Listeners
document.addEventListener('DOMContentLoaded', function() {
  // Initialize app
  appState.updateCartUI();
  appState.updateAuthUI();
  
  // Check if user is already logged in
  if (appState.token) {
    ApiService.getProfile()
      .then(response => {
        appState.setUser(response.user || response);
      })
      .catch(() => {
        appState.setToken(null);
      });
  }
  
  // Connect WebSocket
  wsService.connect();
  
  // Add sample products for demo (after a short delay to ensure backend is ready)
  setTimeout(() => {
    if (appState.user) {
      addSampleProducts();
    }
  }, 2000);
  
  // Navigation event listeners
  document.addEventListener('click', function(e) {
    if (e.target.matches('a[href^="#"]')) {
      e.preventDefault();
      const target = e.target.getAttribute('href').substring(1);
      showView(target);
    }
  });
  
  // Modal event listeners
  document.querySelectorAll('.modal .close').forEach(closeBtn => {
    closeBtn.addEventListener('click', function() {
      this.closest('.modal').style.display = 'none';
    });
  });
  
  // Click outside modal to close
  document.querySelectorAll('.modal').forEach(modal => {
    modal.addEventListener('click', function(e) {
      if (e.target === this) {
        this.style.display = 'none';
      }
    });
  });
  
  // Form event listeners
  document.getElementById('loginForm').addEventListener('submit', handleLogin);
  document.getElementById('registerForm').addEventListener('submit', handleRegister);
  document.getElementById('productForm').addEventListener('submit', handleProductForm);
  
  // Button event listeners
  document.getElementById('loginBtn').addEventListener('click', () => openModal('loginModal'));
  document.getElementById('registerBtn').addEventListener('click', () => openModal('registerModal'));
  document.getElementById('logoutBtn').addEventListener('click', handleLogout);
  document.getElementById('addProductBtn').addEventListener('click', showAddProductModal);
  document.getElementById('checkoutBtn').addEventListener('click', checkout);
  
  // Cart event listeners
  document.querySelector('.cart-icon').addEventListener('click', openCart);
  document.getElementById('closeCart').addEventListener('click', closeCart);
  
  // Search and filter event listeners
  document.getElementById('searchInput').addEventListener('input', debounce(loadProducts, 300));
  document.getElementById('categoryFilter').addEventListener('change', loadProducts);
  document.getElementById('orderStatusFilter').addEventListener('change', function() {
    const status = this.value;
    const filteredOrders = status 
      ? appState.orders.filter(order => order.status === status)
      : appState.orders;
    renderOrders(filteredOrders);
  });
  
  // Initial load
  showView('home');
  loadProducts();
});

// Utility function for debouncing
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// Sample products for demo purposes
async function addSampleProducts() {
  if (!appState.user || appState.products.length > 0) return;
  
  const sampleProducts = [
    {
      name: "MacBook Pro 16\"",
      description: "Apple MacBook Pro with M2 Pro chip, 16GB RAM, 512GB SSD",
      price: 2499.99,
      category: "electronics",
      stock: 15,
      imageUrl: "https://images.unsplash.com/photo-1541807084-5c52b6b3adef?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80"
    },
    {
      name: "Nike Air Max 270",
      description: "Comfortable running shoes with Air Max technology",
      price: 149.99,
      category: "sports",
      stock: 50,
      imageUrl: "https://images.unsplash.com/photo-1542291026-7eec264c27ff?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80"
    },
    {
      name: "Organic Coffee Beans",
      description: "Premium organic coffee beans from Colombia",
      price: 24.99,
      category: "food",
      stock: 100,
      imageUrl: "https://images.unsplash.com/photo-1559056199-641a0ac8b55e?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80"
    },
    {
      name: "Wireless Earbuds",
      description: "Premium wireless earbuds with noise cancellation",
      price: 199.99,
      category: "electronics",
      stock: 30,
      imageUrl: "https://images.unsplash.com/photo-1572569511254-d8f925fe2cbb?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80"
    },
    {
      name: "Designer Handbag",
      description: "Luxury leather handbag with gold hardware",
      price: 899.99,
      category: "clothing",
      stock: 8,
      imageUrl: "https://images.unsplash.com/photo-1584917865442-de89df76afd3?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80"
    },
    {
      name: "Smart Watch",
      description: "Fitness tracking smartwatch with heart rate monitor",
      price: 349.99,
      category: "electronics",
      stock: 25,
      imageUrl: "https://images.unsplash.com/photo-1523275335684-37898b6baf30?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80"
    }
  ];

  try {
    for (const product of sampleProducts) {
      await ApiService.createProduct(product);
    }
    showToast('Sample products added for demo!', 'success');
    loadProducts();
  } catch (error) {
    console.log('Sample products may already exist or user not authorized');
  }
}

// Cleanup on page unload
window.addEventListener('beforeunload', function() {
  wsService.disconnect();
});
