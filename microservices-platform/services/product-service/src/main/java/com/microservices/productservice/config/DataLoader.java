package com.microservices.productservice.config;

import com.microservices.productservice.model.Product;
import com.microservices.productservice.repository.ProductRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;

@Component
public class DataLoader implements CommandLineRunner {

    @Autowired
    private ProductRepository productRepository;

    @Override
    public void run(String... args) throws Exception {
        // Check if data already exists
        if (productRepository.count() > 0) {
            System.out.println("Sample data already exists, skipping initialization");
            return;
        }

        System.out.println("Loading sample product data...");

        List<Product> sampleProducts = Arrays.asList(
            createProduct("iPhone 15 Pro", "Latest Apple iPhone with A17 Pro chip and titanium design", 
                         new BigDecimal("999.99"), "Electronics", 50, "IPHONE15PRO001",
                         "https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=400"),
            
            createProduct("Samsung Galaxy S24 Ultra", "Premium Android smartphone with S Pen and AI features", 
                         new BigDecimal("1199.99"), "Electronics", 30, "GALAXYS24ULTRA001",
                         "https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=400"),
            
            createProduct("MacBook Air M3", "Ultra-thin laptop powered by Apple M3 chip", 
                         new BigDecimal("1299.99"), "Electronics", 25, "MACBOOKAIRM3001",
                         "https://images.unsplash.com/photo-1541807084-5c52b6b3adef?w=400"),
            
            createProduct("Sony WH-1000XM5", "Premium noise-canceling wireless headphones", 
                         new BigDecimal("399.99"), "Electronics", 75, "SONYWH1000XM5001",
                         "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400"),
            
            createProduct("iPad Pro 12.9\"", "Professional tablet with M2 chip and Liquid Retina display", 
                         new BigDecimal("1099.99"), "Electronics", 40, "IPADPRO129001",
                         "https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?w=400"),
            
            createProduct("Dell XPS 13", "Premium ultrabook with InfinityEdge display", 
                         new BigDecimal("899.99"), "Electronics", 35, "DELLXPS13001",
                         "https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=400"),
            
            createProduct("Gaming Mechanical Keyboard", "RGB backlit mechanical keyboard for gaming", 
                         new BigDecimal("149.99"), "Electronics", 100, "GAMINGKEYBOARD001",
                         "https://images.unsplash.com/photo-1541140532154-b024d705b90a?w=400"),
            
            createProduct("4K Wireless Camera", "Professional 4K camera with wireless connectivity", 
                         new BigDecimal("799.99"), "Electronics", 20, "4KWIRELESSCAM001",
                         "https://images.unsplash.com/photo-1606983340126-99ab4feaa64a?w=400"),
            
            createProduct("Smart Watch Series 9", "Advanced fitness and health tracking smartwatch", 
                         new BigDecimal("349.99"), "Electronics", 60, "SMARTWATCH9001",
                         "https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400"),
            
            createProduct("Bluetooth Speaker", "Portable waterproof Bluetooth speaker with 360° sound", 
                         new BigDecimal("79.99"), "Electronics", 150, "BLUETOOTHSPK001",
                         "https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=400")
        );

        productRepository.saveAll(sampleProducts);
        System.out.println("Loaded " + sampleProducts.size() + " sample products");
    }

    private Product createProduct(String name, String description, BigDecimal price, 
                                 String category, Integer stock, String sku, String imageUrl) {
        Product product = new Product();
        product.setName(name);
        product.setDescription(description);
        product.setPrice(price);
        product.setCategory(category);
        product.setStock(stock);
        product.setSku(sku);
        product.setImageUrl(imageUrl);
        product.setActive(true);
        product.setCreatedAt(LocalDateTime.now());
        product.setUpdatedAt(LocalDateTime.now());
        return product;
    }
}
