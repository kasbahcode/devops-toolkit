const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Basic middleware
app.use(express.json());
app.use(express.static('public'));

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development'
    });
});

// Main route
app.get('/', (req, res) => {
    res.json({
        message: '🚀 DevOps Toolkit Demo App',
        description: 'This is a sample application to demonstrate the DevOps toolkit',
        endpoints: {
            health: '/health',
            metrics: '/metrics'
        },
        documentation: 'https://github.com/kasbahcode/devops-toolkit'
    });
});

// Metrics endpoint (basic)
app.get('/metrics', (req, res) => {
    res.json({
        nodejs_version: process.version,
        memory_usage: process.memoryUsage(),
        uptime_seconds: process.uptime(),
        timestamp: Date.now()
    });
});

// Error handling
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Something went wrong!' });
});

// Start server
app.listen(port, '0.0.0.0', () => {
    console.log(`🚀 DevOps Toolkit Demo App running on port ${port}`);
    console.log(`📊 Health check: http://localhost:${port}/health`);
    console.log(`📈 Metrics: http://localhost:${port}/metrics`);
});

module.exports = app; 