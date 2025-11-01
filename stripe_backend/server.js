require('dotenv').config();
const express = require('express');
const cors = require('cors');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get('/', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'Stripe Payment Backend is running',
    timestamp: new Date().toISOString()
  });
});

// Create Payment Intent
app.post('/api/create-payment-intent', async (req, res) => {
  try {
    const { amount, currency, description, userId, bookingId, roomId } = req.body;

    // Validate input
    if (!amount || !currency) {
      return res.status(400).json({ error: 'Missing required fields: amount, currency' });
    }

    // Create Payment Intent with Stripe
    const paymentIntent = await stripe.paymentIntents.create({
      amount: parseInt(amount),
      currency: currency.toLowerCase(),
      description: description || 'Payment for booking',
      metadata: {
        userId: userId || '',
        bookingId: bookingId || '',
        roomId: roomId || '',
      },
      automatic_payment_methods: {
        enabled: true,
      },
    });

    console.log('✅ Payment Intent created:', paymentIntent.id);

    res.json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    });
  } catch (error) {
    console.error('❌ Error creating payment intent:', error.message);
    res.status(500).json({ 
      error: 'Failed to create payment intent',
      details: error.message 
    });
  }
});

// Get Payment Intent Status
app.get('/api/payment-intent/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const paymentIntent = await stripe.paymentIntents.retrieve(id);

    res.json({
      id: paymentIntent.id,
      status: paymentIntent.status,
      amount: paymentIntent.amount,
      currency: paymentIntent.currency,
      metadata: paymentIntent.metadata,
    });
  } catch (error) {
    console.error('❌ Error retrieving payment intent:', error.message);
    res.status(500).json({ 
      error: 'Failed to retrieve payment intent',
      details: error.message 
    });
  }
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log('🚀 Stripe Payment Backend');
  console.log('==========================');
  console.log(`📡 Server: http://localhost:${PORT}`);
  console.log(`📱 Android Emulator: http://10.0.2.2:${PORT}`);
  console.log(`💳 Stripe: ${process.env.STRIPE_SECRET_KEY ? '✅ Configured' : '❌ Missing'}`);
  console.log('');
  console.log('Endpoints:');
  console.log(`  POST /api/create-payment-intent`);
  console.log(`  GET  /api/payment-intent/:id`);
  console.log('==========================');
  console.log('');
});

