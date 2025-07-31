const axios = require('axios');

const services = [
  {
    name: 'API Gateway',
    url: 'http://localhost:3001/health',
    port: 3001
  },
  {
    name: 'Auth Service',
    url: 'http://localhost:3000/health',
    port: 3000
  },
  {
    name: 'Product Service',
    url: 'http://localhost:8080/actuator/health',
    port: 8080
  },
  {
    name: 'Order Service',
    url: 'http://localhost:3002/health',
    port: 3002
  }
];

const infrastructure = [
  {
    name: 'PostgreSQL',
    url: 'http://localhost:5432',
    port: 5432,
    check: 'tcp'
  },
  {
    name: 'Redis',
    url: 'http://localhost:6379',
    port: 6379,
    check: 'tcp'
  },
  {
    name: 'Kafka',
    url: 'http://localhost:9092',
    port: 9092,
    check: 'tcp'
  },
  {
    name: 'Prometheus',
    url: 'http://localhost:9090/-/healthy',
    port: 9090
  },
  {
    name: 'Grafana',
    url: 'http://localhost:3001/api/health',
    port: 3001
  }
];

const checkHttpHealth = async (service) => {
  try {
    const response = await axios.get(service.url, {
      timeout: 5000,
      validateStatus: (status) => status < 500
    });
    
    return {
      ...service,
      status: 'healthy',
      statusCode: response.status,
      responseTime: Date.now()
    };
  } catch (error) {
    return {
      ...service,
      status: 'unhealthy',
      error: error.message,
      statusCode: error.response?.status || 'N/A'
    };
  }
};

const checkTcpHealth = async (service) => {
  const net = require('net');
  
  return new Promise((resolve) => {
    const socket = new net.Socket();
    const timeout = setTimeout(() => {
      socket.destroy();
      resolve({
        ...service,
        status: 'unhealthy',
        error: 'Connection timeout'
      });
    }, 5000);

    socket.connect(service.port, 'localhost', () => {
      clearTimeout(timeout);
      socket.destroy();
      resolve({
        ...service,
        status: 'healthy'
      });
    });

    socket.on('error', (error) => {
      clearTimeout(timeout);
      resolve({
        ...service,
        status: 'unhealthy',
        error: error.message
      });
    });
  });
};

const printHealthStatus = (results, title) => {
  console.log(`\n${title}:`);
  console.log('='.repeat(50));
  
  results.forEach(result => {
    const status = result.status === 'healthy' ? '✅' : '❌';
    const statusText = result.status.toUpperCase().padEnd(10);
    const name = result.name.padEnd(20);
    
    let details = '';
    if (result.statusCode) {
      details += ` [${result.statusCode}]`;
    }
    if (result.error) {
      details += ` - ${result.error}`;
    }
    
    console.log(`${status} ${statusText} ${name} :${result.port}${details}`);
  });
};

const printSummary = (serviceResults, infraResults) => {
  const healthyServices = serviceResults.filter(s => s.status === 'healthy').length;
  const totalServices = serviceResults.length;
  const healthyInfra = infraResults.filter(s => s.status === 'healthy').length;
  const totalInfra = infraResults.length;
  
  console.log('\n' + '='.repeat(50));
  console.log('HEALTH CHECK SUMMARY');
  console.log('='.repeat(50));
  console.log(`Microservices: ${healthyServices}/${totalServices} healthy`);
  console.log(`Infrastructure: ${healthyInfra}/${totalInfra} healthy`);
  
  const allHealthy = healthyServices === totalServices && healthyInfra === totalInfra;
  console.log(`\nOverall Status: ${allHealthy ? '✅ ALL SYSTEMS HEALTHY' : '❌ SOME SYSTEMS UNHEALTHY'}`);
  
  if (!allHealthy) {
    console.log('\n💡 Troubleshooting tips:');
    console.log('   - Run "npm run docker:up" to start infrastructure');
    console.log('   - Run "npm run dev" to start microservices');
    console.log('   - Check logs with "npm run logs"');
    console.log('   - Ensure all dependencies are installed with "npm run install:all"');
  }
};

const main = async () => {
  console.log('🏥 Checking health of all services...\n');
  
  try {
    // Check microservices
    const servicePromises = services.map(checkHttpHealth);
    const serviceResults = await Promise.all(servicePromises);
    
    // Check infrastructure
    const infraPromises = infrastructure.map(service => 
      service.check === 'tcp' ? checkTcpHealth(service) : checkHttpHealth(service)
    );
    const infraResults = await Promise.all(infraPromises);
    
    // Print results
    printHealthStatus(serviceResults, 'MICROSERVICES');
    printHealthStatus(infraResults, 'INFRASTRUCTURE');
    printSummary(serviceResults, infraResults);
    
  } catch (error) {
    console.error('❌ Health check failed:', error.message);
    process.exit(1);
  }
};

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { checkHttpHealth, checkTcpHealth };
