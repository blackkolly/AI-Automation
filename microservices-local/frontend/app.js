// Frontend Application for Microservices Platform
class MicroservicesDashboard {
    constructor() {
        this.services = [
            { name: 'api-gateway', url: 'http://localhost:30000/health', port: 30000 },
            { name: 'auth-service', url: 'http://localhost:30001/health', port: 30001 },
            { name: 'product-service', url: 'http://localhost:30002/health', port: 30002 },
            { name: 'order-service', url: 'http://localhost:30003/health', port: 30003 }
        ];
        
        this.init();
        this.startHealthChecks();
    }

    init() {
        // Navigation
        document.getElementById('servicesBtn').addEventListener('click', () => this.showSection('servicesSection'));
        document.getElementById('productsBtn').addEventListener('click', () => this.showSection('productsSection'));
        document.getElementById('ordersBtn').addEventListener('click', () => this.showSection('ordersSection'));
        document.getElementById('monitoringBtn').addEventListener('click', () => this.showSection('monitoringSection'));

        // Initial health check
        this.checkAllServices();
    }

    showSection(sectionId) {
        // Hide all sections
        document.querySelectorAll('.section').forEach(section => {
            section.classList.remove('active');
        });

        // Remove active class from all nav buttons
        document.querySelectorAll('.nav-btn').forEach(btn => {
            btn.classList.remove('active');
        });

        // Show selected section
        document.getElementById(sectionId).classList.add('active');

        // Add active class to corresponding button
        const btnMap = {
            'servicesSection': 'servicesBtn',
            'productsSection': 'productsBtn', 
            'ordersSection': 'ordersBtn',
            'monitoringSection': 'monitoringBtn'
        };
        document.getElementById(btnMap[sectionId]).classList.add('active');
    }

    async checkAllServices() {
        let healthyCount = 0;
        let totalServices = this.services.length;

        for (const service of this.services) {
            try {
                const isHealthy = await this.checkServiceHealth(service.name, service.url);
                if (isHealthy) healthyCount++;
            } catch (error) {
                console.warn(`Health check failed for ${service.name}:`, error);
            }
        }

        this.updateOverallStatus(healthyCount, totalServices);
    }

    async checkServiceHealth(serviceName, url) {
        try {
            const response = await fetch(url, {
                method: 'GET',
                mode: 'cors',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            const isHealthy = response.ok;
            this.updateServiceStatus(serviceName, isHealthy);
            return isHealthy;
        } catch (error) {
            console.warn(`Service ${serviceName} is not accessible:`, error);
            this.updateServiceStatus(serviceName, false);
            return false;
        }
    }

    updateServiceStatus(serviceName, isHealthy) {
        const statusElement = document.getElementById(`${serviceName}-status`);
        const cardElement = document.getElementById(`${serviceName}-card`);
        
        if (statusElement) {
            statusElement.className = `status-indicator ${isHealthy ? 'healthy' : 'error'}`;
            statusElement.title = isHealthy ? 'Service is healthy' : 'Service is not responding';
        }

        if (cardElement) {
            cardElement.style.borderLeftColor = isHealthy ? '#4CAF50' : '#f44336';
        }
    }

    updateOverallStatus(healthyCount, totalServices) {
        const statusElement = document.getElementById('overall-status');
        
        if (healthyCount === totalServices) {
            statusElement.textContent = 'All Systems Operational';
            statusElement.className = 'healthy';
        } else if (healthyCount === 0) {
            statusElement.textContent = 'All Systems Down';
            statusElement.className = 'error';
        } else {
            statusElement.textContent = `${healthyCount}/${totalServices} Services Running`;
            statusElement.className = 'warning';
        }
    }

    startHealthChecks() {
        // Check services every 30 seconds
        setInterval(() => {
            this.checkAllServices();
        }, 30000);
    }

    async loadProducts() {
        const productsContainer = document.getElementById('products-list');
        productsContainer.innerHTML = '<div class="loading"></div>';

        try {
            const response = await fetch('http://localhost:30002/products');
            if (response.ok) {
                const products = await response.json();
                this.displayProducts(products);
            } else {
                throw new Error('Failed to fetch products');
            }
        } catch (error) {
            productsContainer.innerHTML = `
                <div class="error-message">
                    <p>Unable to load products. Make sure the Product Service is running.</p>
                    <small>Error: ${error.message}</small>
                </div>
            `;
        }
    }

    displayProducts(products) {
        const container = document.getElementById('products-list');
        
        if (!products || products.length === 0) {
            container.innerHTML = '<p>No products available.</p>';
            return;
        }

        container.innerHTML = products.map(product => `
            <div class="product-card">
                <h4>${product.name}</h4>
                <p>Category: ${product.category}</p>
                <p class="price">$${product.price}</p>
                <small>ID: ${product.id}</small>
            </div>
        `).join('');
    }

    async loadOrders() {
        const ordersContainer = document.getElementById('orders-list');
        ordersContainer.innerHTML = '<div class="loading"></div>';

        try {
            const response = await fetch('http://localhost:30003/orders');
            if (response.ok) {
                const orders = await response.json();
                this.displayOrders(orders);
            } else {
                throw new Error('Failed to fetch orders');
            }
        } catch (error) {
            ordersContainer.innerHTML = `
                <div class="error-message">
                    <p>Unable to load orders. Make sure the Order Service is running.</p>
                    <small>Error: ${error.message}</small>
                </div>
            `;
        }
    }

    displayOrders(orders) {
        const container = document.getElementById('orders-list');
        
        if (!orders || orders.length === 0) {
            container.innerHTML = '<p>No orders available.</p>';
            return;
        }

        container.innerHTML = orders.map(order => `
            <div class="order-card">
                <h4>Order #${order.id}</h4>
                <p>Customer: ${order.customer || 'N/A'}</p>
                <p>Status: ${order.status || 'Pending'}</p>
                <p class="price">$${order.total || '0.00'}</p>
                <small>Date: ${order.date || 'N/A'}</small>
            </div>
        `).join('');
    }
}

// Global functions for inline event handlers
function testService(serviceName, url) {
    const dashboard = window.dashboard;
    dashboard.checkServiceHealth(serviceName, url);
}

function loadProducts() {
    window.dashboard.loadProducts();
}

function loadOrders() {
    window.dashboard.loadOrders();
}

// Initialize the dashboard when page loads
document.addEventListener('DOMContentLoaded', () => {
    window.dashboard = new MicroservicesDashboard();
    
    // Show welcome message
    console.log('🚀 Microservices Platform Dashboard Loaded');
    console.log('🔗 Available endpoints:');
    console.log('   • API Gateway: http://localhost:30000');
    console.log('   • Auth Service: http://localhost:30001'); 
    console.log('   • Product Service: http://localhost:30002');
    console.log('   • Order Service: http://localhost:30003');
    console.log('📊 Monitoring:');
    console.log('   • Grafana: http://localhost:30300');
    console.log('   • Prometheus: http://localhost:30090');
    console.log('   • Jaeger: http://localhost:30686');
});
