// Simple test to validate our testing framework works
// This test runs without external dependencies

console.log('🧪 Testing Framework Validation');
console.log('==============================');

// Simple function to test
function add(a, b) {
  return a + b;
}

function multiply(a, b) {
  return a * b;
}

function validateEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// Simple test runner
function runTest(name, testFn) {
  try {
    const result = testFn();
    if (result) {
      console.log(`✅ PASSED: ${name}`);
      return true;
    } else {
      console.log(`❌ FAILED: ${name}`);
      return false;
    }
  } catch (error) {
    console.log(`❌ ERROR: ${name} - ${error.message}`);
    return false;
  }
}

// Run tests
console.log('\n📋 Running Basic Function Tests:');
let passed = 0;
let total = 0;

// Test 1: Addition
total++;
if (runTest('Addition function', () => add(2, 3) === 5)) passed++;

// Test 2: Multiplication
total++;
if (runTest('Multiplication function', () => multiply(4, 5) === 20)) passed++;

// Test 3: Email validation - valid email
total++;
if (runTest('Valid email validation', () => validateEmail('test@example.com'))) passed++;

// Test 4: Email validation - invalid email
total++;
if (runTest('Invalid email validation', () => !validateEmail('invalid-email'))) passed++;

// Test 5: Edge case - zero
total++;
if (runTest('Addition with zero', () => add(5, 0) === 5)) passed++;

console.log('\n📊 Test Results:');
console.log(`✅ Passed: ${passed}`);
console.log(`❌ Failed: ${total - passed}`);
console.log(`📈 Success Rate: ${Math.round((passed / total) * 100)}%`);

if (passed === total) {
  console.log('\n🎉 All tests passed! Testing framework is working correctly.');
  process.exit(0);
} else {
  console.log('\n⚠️  Some tests failed. Please check the implementation.');
  process.exit(1);
}
