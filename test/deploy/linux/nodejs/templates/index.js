// index.js

// Load the New Relic agent before anything else
require('newrelic');

const express = require('express');
const app = express();
const PORT = process.env.PORT || 3030;

// Simple route for testing
app.get('/', (req, res) => {
    res.send('Hello World! This is my Node.js app instrumented with New Relic.');
});

// Start the server
app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});