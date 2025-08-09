const path = require('path');

module.exports = {
  // Test environment
  testEnvironment: 'node',
  
  // Root directory for tests
  rootDir: '.',
  
  // Test file patterns
  testMatch: [
    '<rootDir>/unit/**/*.test.{js,ts}',
    '<rootDir>/integration/**/*.test.{js,ts}',
    '<rootDir>/smoke/**/*.test.{js,ts}'
  ],
  
  // Ignore patterns
  testPathIgnorePatterns: [
    '<rootDir>/node_modules/',
    '<rootDir>/e2e/',
    '<rootDir>/performance/',
    '<rootDir>/security/',
    '<rootDir>/build/',
    '<rootDir>/dist/'
  ],
  
  // Module file extensions
  moduleFileExtensions: ['js', 'json', 'ts'],
  
  // Transform files
  transform: {
    '^.+\\.(ts|tsx)$': 'ts-jest',
    '^.+\\.(js|jsx)$': 'babel-jest'
  },
  
  // Module name mapping
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '^@config/(.*)$': '<rootDir>/config/$1',
    '^@utils/(.*)$': '<rootDir>/utils/$1',
    '^@mocks/(.*)$': '<rootDir>/unit/mocks/$1'
  },
  
  // Setup files
  setupFilesAfterEnv: [
    '<rootDir>/config/jest.setup.js'
  ],
  
  // Coverage configuration
  collectCoverage: true,
  collectCoverageFrom: [
    'src/**/*.{js,ts}',
    '!src/**/*.d.ts',
    '!src/**/*.interface.ts',
    '!src/**/*.enum.ts',
    '!src/**/*.config.ts',
    '!src/main.ts',
    '!src/app.ts'
  ],
  
  // Coverage thresholds
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 90,
      lines: 90,
      statements: 90
    },
    './src/services/': {
      branches: 85,
      functions: 95,
      lines: 95,
      statements: 95
    },
    './src/controllers/': {
      branches: 80,
      functions: 90,
      lines: 90,
      statements: 90
    }
  },
  
  // Coverage directories
  coverageDirectory: '<rootDir>/coverage',
  
  // Coverage reporters
  coverageReporters: [
    'text',
    'text-summary',
    'html',
    'lcov',
    'json',
    'clover'
  ],
  
  // Test reporters
  reporters: [
    'default',
    [
      'jest-html-reporter',
      {
        pageTitle: 'Kubernetes Microservices Test Report',
        outputPath: './reports/test-report.html',
        includeFailureMsg: true,
        includeSuiteFailure: true,
        includeConsoleLog: true
      }
    ],
    [
      'jest-junit',
      {
        outputDirectory: './reports',
        outputName: 'junit.xml',
        suiteName: 'Kubernetes Microservices Tests',
        classNameTemplate: '{classname}',
        titleTemplate: '{title}',
        ancestorSeparator: ' › ',
        usePathForSuiteName: true
      }
    ]
  ],
  
  // Global variables
  globals: {
    'ts-jest': {
      tsconfig: 'tsconfig.json'
    }
  },
  
  // Test timeout
  testTimeout: 30000,
  
  // Verbose output
  verbose: true,
  
  // Clear mocks between tests
  clearMocks: true,
  
  // Restore mocks after each test
  restoreMocks: true,
  
  // Reset modules between tests
  resetModules: true,
  
  // Force exit after tests complete
  forceExit: true,
  
  // Detect open handles
  detectOpenHandles: true,
  
  // Error on deprecated features
  errorOnDeprecated: true,
  
  // Fail fast on first test failure (CI only)
  bail: process.env.CI ? 1 : 0,
  
  // Cache directory
  cacheDirectory: '<rootDir>/.jest-cache',
  
  // Watch plugins
  watchPlugins: [
    'jest-watch-typeahead/filename',
    'jest-watch-typeahead/testname'
  ],
  
  // Max worker processes
  maxWorkers: process.env.CI ? 2 : '50%',
  
  // Test result processor
  testResultsProcessor: './scripts/test-results-processor.js'
};
