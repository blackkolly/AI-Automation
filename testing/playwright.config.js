const { defineConfig, devices } = require('@playwright/test');

/**
 * Playwright Configuration for End-to-End Testing
 * 
 * This configuration supports:
 * - Cross-browser testing (Chrome, Firefox, Safari, Edge)
 * - Mobile device simulation
 * - Visual regression testing
 * - API testing integration
 * - Parallel test execution
 * - Test retry mechanisms
 * - Comprehensive reporting
 */

module.exports = defineConfig({
  // Test directory
  testDir: './e2e',
  
  // Global test timeout
  timeout: 30 * 1000, // 30 seconds
  
  // Expect timeout for assertions
  expect: {
    timeout: 10 * 1000, // 10 seconds
  },
  
  // Test execution configuration
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 2 : undefined,
  
  // Reporter configuration
  reporter: [
    ['html', { 
      outputFolder: 'reports/playwright-report',
      open: process.env.CI ? 'never' : 'on-failure'
    }],
    ['json', { 
      outputFile: 'reports/playwright-results.json' 
    }],
    ['junit', { 
      outputFile: 'reports/playwright-junit.xml' 
    }],
    ['list'],
    ...(process.env.CI ? [['github']] : [])
  ],
  
  // Global setup and teardown
  globalSetup: require.resolve('./config/global-setup.js'),
  globalTeardown: require.resolve('./config/global-teardown.js'),
  
  // Use browser configuration
  use: {
    // Browser context options
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    
    // Emulate timezone
    timezoneId: 'UTC',
    
    // Browser viewport
    viewport: { width: 1280, height: 720 },
    
    // Enable screenshots and videos on failure
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
    
    // Browser settings
    actionTimeout: 15 * 1000, // 15 seconds
    navigationTimeout: 30 * 1000, // 30 seconds
    
    // Network settings
    ignoreHTTPSErrors: true,
    
    // User agent
    userAgent: 'Playwright E2E Tests',
    
    // Extra HTTP headers
    extraHTTPHeaders: {
      'Accept-Language': 'en-US,en;q=0.9',
    },
  },

  // Browser projects configuration
  projects: [
    // Desktop Browsers
    {
      name: 'chromium',
      use: { 
        ...devices['Desktop Chrome'],
        channel: 'chrome'
      },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'edge',
      use: { 
        ...devices['Desktop Edge'],
        channel: 'msedge'
      },
    },

    // Mobile Browsers
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] },
    },

    // Tablet Browsers
    {
      name: 'iPad',
      use: { ...devices['iPad Pro'] },
    },

    // API Testing Project
    {
      name: 'api-tests',
      testDir: './e2e/api',
      use: {
        baseURL: process.env.API_BASE_URL || 'http://localhost:3001/api',
      },
    },

    // Visual Regression Testing
    {
      name: 'visual-tests',
      testDir: './e2e/visual',
      use: {
        ...devices['Desktop Chrome'],
        screenshot: 'only-on-failure',
      },
    },

    // Performance Testing
    {
      name: 'performance-tests',
      testDir: './e2e/performance',
      use: {
        ...devices['Desktop Chrome'],
      },
    },

    // Accessibility Testing
    {
      name: 'accessibility-tests',
      testDir: './e2e/accessibility',
      use: {
        ...devices['Desktop Chrome'],
      },
    }
  ],

  // Development server configuration
  webServer: process.env.CI ? undefined : {
    command: 'npm run start:test',
    port: 3000,
    timeout: 120 * 1000, // 2 minutes
    reuseExistingServer: !process.env.CI,
    env: {
      NODE_ENV: 'test',
      PORT: '3000'
    }
  },

  // Test output directory
  outputDir: 'test-results/',
  
  // Test metadata
  metadata: {
    testType: 'e2e',
    environment: process.env.TEST_ENV || 'local',
    browser: 'multi-browser',
    platform: process.platform,
    nodeVersion: process.version
  }
});
