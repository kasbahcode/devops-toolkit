import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('errors');
export let responseTime = new Trend('response_time');
export let requests = new Counter('requests');

// Test configuration
export let options = {
  stages: [
    // Ramp-up
    { duration: '2m', target: 10 }, // Ramp up to 10 users over 2 minutes
    { duration: '5m', target: 10 }, // Stay at 10 users for 5 minutes
    { duration: '2m', target: 20 }, // Ramp up to 20 users over 2 minutes
    { duration: '5m', target: 20 }, // Stay at 20 users for 5 minutes
    { duration: '2m', target: 50 }, // Ramp up to 50 users over 2 minutes
    { duration: '5m', target: 50 }, // Stay at 50 users for 5 minutes
    // Ramp-down
    { duration: '2m', target: 0 },  // Ramp down to 0 users over 2 minutes
  ],
  thresholds: {
    // Performance thresholds
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.05'],   // Error rate should be less than 5%
    errors: ['rate<0.05'],            // Custom error rate should be less than 5%
  },
  ext: {
    loadimpact: {
      projectID: 3596731,
      name: 'DevOps Toolkit Load Test'
    }
  }
};

// Base URL - can be overridden with environment variable
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

// Test scenarios
const scenarios = {
  healthCheck: {
    weight: 10,
    exec: 'healthCheck'
  },
  homePage: {
    weight: 30,
    exec: 'homePage'
  },
  apiStatus: {
    weight: 20,
    exec: 'apiStatus'
  },
  userJourney: {
    weight: 40,
    exec: 'userJourney'
  }
};

// Setup function - runs once before the test
export function setup() {
  console.log('🚀 Starting load test against:', BASE_URL);
  
  // Verify the service is available
  let response = http.get(`${BASE_URL}/health`);
  if (response.status !== 200) {
    throw new Error(`Service not available. Status: ${response.status}`);
  }
  
  console.log('✅ Service is available, starting load test...');
  return { baseUrl: BASE_URL };
}

// Health check scenario
export function healthCheck(data) {
  let response = http.get(`${data.baseUrl}/health`);
  
  let success = check(response, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 100ms': (r) => r.timings.duration < 100,
    'health check has correct content': (r) => r.json('status') === 'OK',
  });
  
  // Record metrics
  errorRate.add(!success);
  responseTime.add(response.timings.duration);
  requests.add(1);
  
  sleep(1);
}

// Home page scenario
export function homePage(data) {
  let response = http.get(`${data.baseUrl}/`);
  
  let success = check(response, {
    'home page status is 200': (r) => r.status === 200,
    'home page response time < 500ms': (r) => r.timings.duration < 500,
    'home page has welcome message': (r) => r.json('message').includes('Welcome'),
  });
  
  // Record metrics
  errorRate.add(!success);
  responseTime.add(response.timings.duration);
  requests.add(1);
  
  sleep(1);
}

// API status scenario
export function apiStatus(data) {
  let response = http.get(`${data.baseUrl}/api/status`);
  
  let success = check(response, {
    'API status is 200': (r) => r.status === 200,
    'API response time < 300ms': (r) => r.timings.duration < 300,
    'API has status field': (r) => r.json('status') === 'running',
    'API has uptime field': (r) => r.json('uptime') !== undefined,
  });
  
  // Record metrics
  errorRate.add(!success);
  responseTime.add(response.timings.duration);
  requests.add(1);
  
  sleep(1);
}

// User journey scenario
export function userJourney(data) {
  let group = 'User Journey';
  
  // Step 1: Visit home page
  let homeResponse = http.get(`${data.baseUrl}/`);
  check(homeResponse, {
    [`${group} - Home page loads`]: (r) => r.status === 200,
  });
  
  sleep(1);
  
  // Step 2: Check health
  let healthResponse = http.get(`${data.baseUrl}/health`);
  check(healthResponse, {
    [`${group} - Health check passes`]: (r) => r.status === 200,
  });
  
  sleep(1);
  
  // Step 3: Get API status
  let statusResponse = http.get(`${data.baseUrl}/api/status`);
  check(statusResponse, {
    [`${group} - API status accessible`]: (r) => r.status === 200,
  });
  
  // Record overall journey success
  let journeySuccess = homeResponse.status === 200 && 
                      healthResponse.status === 200 && 
                      statusResponse.status === 200;
  
  errorRate.add(!journeySuccess);
  requests.add(3); // 3 requests in this journey
  
  sleep(2);
}

// Stress test scenario (can be run separately)
export function stressTest(data) {
  // Rapid fire requests to test system limits
  for (let i = 0; i < 10; i++) {
    let response = http.get(`${data.baseUrl}/api/status`);
    check(response, {
      'stress test request successful': (r) => r.status === 200,
    });
    
    errorRate.add(response.status !== 200);
    responseTime.add(response.timings.duration);
    requests.add(1);
    
    sleep(0.1); // Very short sleep
  }
}

// Spike test scenario
export function spikeTest(data) {
  // Simulate traffic spikes
  let responses = http.batch([
    ['GET', `${data.baseUrl}/`],
    ['GET', `${data.baseUrl}/health`],
    ['GET', `${data.baseUrl}/api/status`],
    ['GET', `${data.baseUrl}/`],
    ['GET', `${data.baseUrl}/health`],
  ]);
  
  let allSuccess = true;
  responses.forEach((response, index) => {
    let success = check(response, {
      [`spike test ${index} status is 200`]: (r) => r.status === 200,
    });
    
    if (!success) allSuccess = false;
    responseTime.add(response.timings.duration);
    requests.add(1);
  });
  
  errorRate.add(!allSuccess);
  sleep(1);
}

// Default test function
export default function(data) {
  // Randomly choose a scenario based on weights
  let rand = Math.random() * 100;
  
  if (rand < 10) {
    healthCheck(data);
  } else if (rand < 40) {
    homePage(data);
  } else if (rand < 60) {
    apiStatus(data);
  } else {
    userJourney(data);
  }
}

// Teardown function - runs once after the test
export function teardown(data) {
  console.log('🏁 Load test completed');
  
  // Final health check
  let response = http.get(`${data.baseUrl}/health`);
  if (response.status === 200) {
    console.log('✅ Service is still healthy after load test');
  } else {
    console.log('⚠️ Service may be impacted after load test');
  }
} 