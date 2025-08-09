/**
 * OWASP ZAP Security Testing Automation
 * 
 * This script automates security testing using OWASP ZAP (Zed Attack Proxy)
 * to identify common web application vulnerabilities including:
 * - SQL Injection
 * - Cross-Site Scripting (XSS)
 * - Cross-Site Request Forgery (CSRF)
 * - Authentication bypasses
 * - Authorization flaws
 * - Information disclosure
 * - Security misconfiguration
 */

const ZapClient = require('zap-client');
const fs = require('fs');
const path = require('path');

class SecurityTestSuite {
  constructor() {
    this.zapClient = new ZapClient({
      host: process.env.ZAP_HOST || 'localhost',
      port: process.env.ZAP_PORT || 8080
    });
    
    this.targetUrl = process.env.TARGET_URL || 'http://localhost:3000';
    this.apiUrl = process.env.API_URL || 'http://localhost:3001';
    this.reportsDir = path.join(__dirname, '..', 'reports');
    
    this.testResults = {
      timestamp: new Date().toISOString(),
      targetUrl: this.targetUrl,
      apiUrl: this.apiUrl,
      vulnerabilities: [],
      summary: {}
    };
  }

  async initialize() {
    console.log('🔒 Initializing OWASP ZAP Security Testing...');
    
    // Ensure reports directory exists
    if (!fs.existsSync(this.reportsDir)) {
      fs.mkdirSync(this.reportsDir, { recursive: true });
    }

    try {
      // Check ZAP connection
      const version = await this.zapClient.core.version();
      console.log(`✅ Connected to OWASP ZAP version: ${version}`);
      
      // Create new session
      await this.zapClient.core.newSession('security-test-session');
      console.log('📝 Created new ZAP session');
      
      return true;
    } catch (error) {
      console.error('❌ Failed to initialize ZAP:', error.message);
      console.log('💡 Make sure OWASP ZAP is running on http://localhost:8080');
      return false;
    }
  }

  async runSpiderScan() {
    console.log('🕷️ Running Spider Scan to discover endpoints...');
    
    try {
      // Start spider scan
      const spiderId = await this.zapClient.spider.scan(this.targetUrl);
      console.log(`📡 Spider scan started with ID: ${spiderId}`);
      
      // Wait for spider to complete
      let progress = 0;
      while (progress < 100) {
        await this.sleep(5000); // Wait 5 seconds
        progress = await this.zapClient.spider.status(spiderId);
        console.log(`🔍 Spider progress: ${progress}%`);
      }
      
      // Get spider results
      const urls = await this.zapClient.spider.results(spiderId);
      console.log(`📊 Spider discovered ${urls.length} URLs`);
      
      this.testResults.discoveredUrls = urls.length;
      return urls;
    } catch (error) {
      console.error('❌ Spider scan failed:', error.message);
      return [];
    }
  }

  async runActiveScan() {
    console.log('⚡ Running Active Security Scan...');
    
    try {
      // Configure scan policy for comprehensive testing
      await this.configureScanPolicy();
      
      // Start active scan
      const scanId = await this.zapClient.ascan.scan(this.targetUrl);
      console.log(`🎯 Active scan started with ID: ${scanId}`);
      
      // Monitor scan progress
      let progress = 0;
      while (progress < 100) {
        await this.sleep(10000); // Wait 10 seconds
        progress = await this.zapClient.ascan.status(scanId);
        console.log(`⚡ Active scan progress: ${progress}%`);
      }
      
      console.log('✅ Active scan completed');
      return scanId;
    } catch (error) {
      console.error('❌ Active scan failed:', error.message);
      return null;
    }
  }

  async configureScanPolicy() {
    console.log('⚙️ Configuring scan policy...');
    
    try {
      // Enable all vulnerability checks
      const policyName = 'comprehensive-security-policy';
      
      // Create scan policy
      await this.zapClient.ascan.addScanPolicy(policyName);
      
      // Enable specific vulnerability checks
      const vulnerabilityChecks = [
        { id: '40018', name: 'SQL Injection', enabled: true },
        { id: '40012', name: 'Cross Site Scripting (XSS)', enabled: true },
        { id: '40016', name: 'Cross Site Request Forgery (CSRF)', enabled: true },
        { id: '40019', name: 'Server Side Include', enabled: true },
        { id: '40020', name: 'External Redirect', enabled: true },
        { id: '40021', name: 'Source Code Disclosure', enabled: true },
        { id: '40022', name: 'Authentication Bypass', enabled: true },
        { id: '40023', name: 'Directory Browsing', enabled: true },
        { id: '40024', name: 'Parameter Tampering', enabled: true },
        { id: '40025', name: 'Buffer Overflow', enabled: true }
      ];
      
      for (const check of vulnerabilityChecks) {
        try {
          await this.zapClient.ascan.enableScanners(check.id, policyName);
          console.log(`✅ Enabled: ${check.name}`);
        } catch (error) {
          console.warn(`⚠️ Could not enable ${check.name}: ${error.message}`);
        }
      }
      
      console.log('✅ Scan policy configured');
    } catch (error) {
      console.error('❌ Failed to configure scan policy:', error.message);
    }
  }

  async runAPISecurityTests() {
    console.log('🔌 Running API Security Tests...');
    
    try {
      // Test common API vulnerabilities
      await this.testAPIAuthentication();
      await this.testAPIAuthorization();
      await this.testAPIInputValidation();
      await this.testAPIRateLimiting();
      await this.testAPIInformationDisclosure();
      
      console.log('✅ API security tests completed');
    } catch (error) {
      console.error('❌ API security tests failed:', error.message);
    }
  }

  async testAPIAuthentication() {
    console.log('🔐 Testing API Authentication...');
    
    const authTests = [
      {
        name: 'Access protected endpoint without token',
        url: `${this.apiUrl}/api/users/me`,
        expectedStatus: 401
      },
      {
        name: 'Access protected endpoint with invalid token',
        url: `${this.apiUrl}/api/users/me`,
        headers: { 'Authorization': 'Bearer invalid.jwt.token' },
        expectedStatus: 401
      },
      {
        name: 'SQL injection in login',
        url: `${this.apiUrl}/api/auth/login`,
        method: 'POST',
        data: { email: "admin'--", password: "anything" },
        expectedStatus: [400, 401, 404]
      }
    ];
    
    for (const test of authTests) {
      try {
        const result = await this.sendTestRequest(test);
        this.recordTestResult('Authentication', test.name, result);
      } catch (error) {
        console.error(`❌ Auth test failed: ${test.name}`, error.message);
      }
    }
  }

  async testAPIAuthorization() {
    console.log('🛡️ Testing API Authorization...');
    
    // First, create test users with different roles
    const user1Token = await this.createTestUser('user1@test.com', 'user');
    const user2Token = await this.createTestUser('user2@test.com', 'user');
    const adminToken = await this.createTestUser('admin@test.com', 'admin');
    
    const authzTests = [
      {
        name: 'User accessing another user\'s data',
        url: `${this.apiUrl}/api/users/OTHER_USER_ID`,
        headers: { 'Authorization': `Bearer ${user1Token}` },
        expectedStatus: [403, 404]
      },
      {
        name: 'Regular user accessing admin endpoint',
        url: `${this.apiUrl}/api/admin/users`,
        headers: { 'Authorization': `Bearer ${user1Token}` },
        expectedStatus: 403
      },
      {
        name: 'Admin accessing admin endpoint',
        url: `${this.apiUrl}/api/admin/users`,
        headers: { 'Authorization': `Bearer ${adminToken}` },
        expectedStatus: 200
      }
    ];
    
    for (const test of authzTests) {
      try {
        const result = await this.sendTestRequest(test);
        this.recordTestResult('Authorization', test.name, result);
      } catch (error) {
        console.error(`❌ Authorization test failed: ${test.name}`, error.message);
      }
    }
  }

  async testAPIInputValidation() {
    console.log('🧪 Testing API Input Validation...');
    
    const inputTests = [
      {
        name: 'XSS in user registration',
        url: `${this.apiUrl}/api/users`,
        method: 'POST',
        data: {
          email: 'xss@test.com',
          name: '<script>alert("XSS")</script>',
          password: 'Password123!'
        },
        expectedStatus: [400, 422]
      },
      {
        name: 'SQL injection in user search',
        url: `${this.apiUrl}/api/users/search?q='; DROP TABLE users; --`,
        expectedStatus: [400, 422]
      },
      {
        name: 'Command injection in file upload',
        url: `${this.apiUrl}/api/upload`,
        method: 'POST',
        data: { filename: '../../etc/passwd' },
        expectedStatus: [400, 422]
      },
      {
        name: 'LDAP injection in authentication',
        url: `${this.apiUrl}/api/auth/login`,
        method: 'POST',
        data: { email: '*)(uid=*))(|(uid=*', password: 'anything' },
        expectedStatus: [400, 401]
      }
    ];
    
    for (const test of inputTests) {
      try {
        const result = await this.sendTestRequest(test);
        this.recordTestResult('Input Validation', test.name, result);
      } catch (error) {
        console.error(`❌ Input validation test failed: ${test.name}`, error.message);
      }
    }
  }

  async testAPIRateLimiting() {
    console.log('🚦 Testing API Rate Limiting...');
    
    try {
      const endpoint = `${this.apiUrl}/api/auth/login`;
      const requests = [];
      
      // Send 100 requests rapidly
      for (let i = 0; i < 100; i++) {
        requests.push(
          this.sendTestRequest({
            url: endpoint,
            method: 'POST',
            data: { email: 'test@test.com', password: 'wrongpassword' }
          })
        );
      }
      
      const results = await Promise.all(requests);
      const rateLimitedRequests = results.filter(r => r.status === 429).length;
      
      this.recordTestResult('Rate Limiting', 'Brute force protection', {
        totalRequests: 100,
        rateLimitedRequests,
        isProtected: rateLimitedRequests > 50
      });
      
    } catch (error) {
      console.error('❌ Rate limiting test failed:', error.message);
    }
  }

  async testAPIInformationDisclosure() {
    console.log('📢 Testing Information Disclosure...');
    
    const disclosureTests = [
      {
        name: 'Error message information leakage',
        url: `${this.apiUrl}/api/users/invalid-user-id-format`,
        expectedNoContent: ['stack trace', 'database error', 'internal server error']
      },
      {
        name: 'API version disclosure',
        url: `${this.apiUrl}/api/version`,
        check: 'should not expose detailed version info'
      },
      {
        name: 'Debug information in headers',
        url: `${this.apiUrl}/api/users`,
        checkHeaders: ['x-powered-by', 'server', 'x-debug-token']
      }
    ];
    
    for (const test of disclosureTests) {
      try {
        const result = await this.sendTestRequest(test);
        this.recordTestResult('Information Disclosure', test.name, result);
      } catch (error) {
        console.error(`❌ Information disclosure test failed: ${test.name}`, error.message);
      }
    }
  }

  async sendTestRequest(testConfig) {
    const axios = require('axios');
    
    try {
      const config = {
        method: testConfig.method || 'GET',
        url: testConfig.url,
        headers: testConfig.headers || {},
        data: testConfig.data,
        timeout: 5000,
        validateStatus: () => true // Don't throw on HTTP error status
      };
      
      const response = await axios(config);
      
      return {
        status: response.status,
        headers: response.headers,
        data: response.data,
        config: testConfig
      };
    } catch (error) {
      return {
        status: 0,
        error: error.message,
        config: testConfig
      };
    }
  }

  async createTestUser(email, role = 'user') {
    try {
      const userData = {
        email,
        name: `Test User ${email}`,
        password: 'TestPassword123!',
        role
      };
      
      const createResponse = await this.sendTestRequest({
        url: `${this.apiUrl}/api/users`,
        method: 'POST',
        data: userData
      });
      
      if (createResponse.status === 201 || createResponse.status === 409) {
        const loginResponse = await this.sendTestRequest({
          url: `${this.apiUrl}/api/auth/login`,
          method: 'POST',
          data: { email, password: userData.password }
        });
        
        if (loginResponse.status === 200) {
          return loginResponse.data.token;
        }
      }
      
      return null;
    } catch (error) {
      console.error(`Failed to create test user ${email}:`, error.message);
      return null;
    }
  }

  recordTestResult(category, testName, result) {
    const testResult = {
      category,
      testName,
      timestamp: new Date().toISOString(),
      ...result
    };
    
    this.testResults.vulnerabilities.push(testResult);
    
    // Log result
    const status = this.evaluateTestResult(result);
    const icon = status === 'PASS' ? '✅' : status === 'FAIL' ? '❌' : '⚠️';
    console.log(`${icon} ${category} - ${testName}: ${status}`);
  }

  evaluateTestResult(result) {
    if (result.error) return 'ERROR';
    if (result.config && result.config.expectedStatus) {
      const expected = Array.isArray(result.config.expectedStatus) 
        ? result.config.expectedStatus 
        : [result.config.expectedStatus];
      return expected.includes(result.status) ? 'PASS' : 'FAIL';
    }
    return 'INFO';
  }

  async generateReports() {
    console.log('📊 Generating security test reports...');
    
    try {
      // Get ZAP alerts
      const alerts = await this.zapClient.core.alerts();
      this.testResults.zapAlerts = alerts;
      
      // Generate summary
      this.testResults.summary = this.generateSummary();
      
      // Save JSON report
      const jsonReport = path.join(this.reportsDir, `security-report-${Date.now()}.json`);
      fs.writeFileSync(jsonReport, JSON.stringify(this.testResults, null, 2));
      
      // Generate HTML report
      const htmlReport = path.join(this.reportsDir, `security-report-${Date.now()}.html`);
      await this.generateHTMLReport(htmlReport);
      
      // Generate ZAP HTML report
      const zapReport = path.join(this.reportsDir, `zap-report-${Date.now()}.html`);
      const zapHtmlReport = await this.zapClient.core.htmlreport();
      fs.writeFileSync(zapReport, zapHtmlReport);
      
      console.log(`📄 Reports generated:`);
      console.log(`   JSON: ${jsonReport}`);
      console.log(`   HTML: ${htmlReport}`);
      console.log(`   ZAP:  ${zapReport}`);
      
    } catch (error) {
      console.error('❌ Failed to generate reports:', error.message);
    }
  }

  generateSummary() {
    const vulnerabilities = this.testResults.vulnerabilities;
    const zapAlerts = this.testResults.zapAlerts || [];
    
    const summary = {
      totalTests: vulnerabilities.length,
      passed: vulnerabilities.filter(v => this.evaluateTestResult(v) === 'PASS').length,
      failed: vulnerabilities.filter(v => this.evaluateTestResult(v) === 'FAIL').length,
      errors: vulnerabilities.filter(v => this.evaluateTestResult(v) === 'ERROR').length,
      zapAlertsCount: zapAlerts.length,
      severityBreakdown: {
        high: zapAlerts.filter(a => a.risk === 'High').length,
        medium: zapAlerts.filter(a => a.risk === 'Medium').length,
        low: zapAlerts.filter(a => a.risk === 'Low').length,
        informational: zapAlerts.filter(a => a.risk === 'Informational').length
      }
    };
    
    summary.passRate = (summary.passed / summary.totalTests * 100).toFixed(2);
    
    return summary;
  }

  async generateHTMLReport(filePath) {
    const html = `
<!DOCTYPE html>
<html>
<head>
    <title>Security Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f5f5f5; padding: 20px; border-radius: 5px; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .metric { background: #e8f4fd; padding: 15px; border-radius: 5px; text-align: center; }
        .pass { background: #d4edda; }
        .fail { background: #f8d7da; }
        .warning { background: #fff3cd; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔒 Security Test Report</h1>
        <p><strong>Target:</strong> ${this.testResults.targetUrl}</p>
        <p><strong>Generated:</strong> ${this.testResults.timestamp}</p>
    </div>
    
    <div class="summary">
        <div class="metric">
            <h3>Total Tests</h3>
            <h2>${this.testResults.summary.totalTests}</h2>
        </div>
        <div class="metric pass">
            <h3>Passed</h3>
            <h2>${this.testResults.summary.passed}</h2>
        </div>
        <div class="metric fail">
            <h3>Failed</h3>
            <h2>${this.testResults.summary.failed}</h2>
        </div>
        <div class="metric warning">
            <h3>Pass Rate</h3>
            <h2>${this.testResults.summary.passRate}%</h2>
        </div>
    </div>
    
    <h2>🚨 ZAP Security Alerts</h2>
    <table>
        <tr>
            <th>Risk</th>
            <th>Alert</th>
            <th>URL</th>
            <th>Description</th>
        </tr>
        ${(this.testResults.zapAlerts || []).map(alert => `
        <tr>
            <td class="${alert.risk.toLowerCase()}">${alert.risk}</td>
            <td>${alert.alert}</td>
            <td>${alert.url}</td>
            <td>${alert.description}</td>
        </tr>
        `).join('')}
    </table>
    
    <h2>🧪 Test Results</h2>
    <table>
        <tr>
            <th>Category</th>
            <th>Test</th>
            <th>Status</th>
            <th>Details</th>
        </tr>
        ${this.testResults.vulnerabilities.map(test => `
        <tr>
            <td>${test.category}</td>
            <td>${test.testName}</td>
            <td class="${this.evaluateTestResult(test).toLowerCase()}">${this.evaluateTestResult(test)}</td>
            <td>Status: ${test.status || 'N/A'}</td>
        </tr>
        `).join('')}
    </table>
</body>
</html>`;
    
    fs.writeFileSync(filePath, html);
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async cleanup() {
    console.log('🧹 Cleaning up security test session...');
    
    try {
      await this.zapClient.core.newSession('cleanup');
      console.log('✅ Cleanup completed');
    } catch (error) {
      console.error('❌ Cleanup failed:', error.message);
    }
  }
}

// Main execution
async function runSecurityTests() {
  const securityTests = new SecurityTestSuite();
  
  try {
    const initialized = await securityTests.initialize();
    if (!initialized) {
      process.exit(1);
    }
    
    // Run all security tests
    await securityTests.runSpiderScan();
    await securityTests.runActiveScan();
    await securityTests.runAPISecurityTests();
    
    // Generate reports
    await securityTests.generateReports();
    
    // Print summary
    console.log('\n📊 Security Test Summary:');
    console.log(`Total Tests: ${securityTests.testResults.summary.totalTests}`);
    console.log(`Passed: ${securityTests.testResults.summary.passed}`);
    console.log(`Failed: ${securityTests.testResults.summary.failed}`);
    console.log(`Pass Rate: ${securityTests.testResults.summary.passRate}%`);
    
    if (securityTests.testResults.summary.failed > 0) {
      console.log('\n❌ Security vulnerabilities detected! Check the reports for details.');
      process.exit(1);
    } else {
      console.log('\n✅ All security tests passed!');
    }
    
  } catch (error) {
    console.error('❌ Security test suite failed:', error.message);
    process.exit(1);
  } finally {
    await securityTests.cleanup();
  }
}

// Run if called directly
if (require.main === module) {
  runSecurityTests();
}

module.exports = SecurityTestSuite;
