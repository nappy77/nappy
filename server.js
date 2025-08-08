const express = require('express');
const path = require('path');
const cors = require('cors');

// Sample product data
const products = [
  {
    _id: '1',
    name: 'Smartphone XYZ',
    description: 'Latest smartphone with advanced features and high-resolution camera.',
    price: 999.99,
    category: 'Smartphones',
    brand: 'TechBrand',
    image: 'https://via.placeholder.com/500x500?text=Smartphone',
    rating: 4.5,
    numReviews: 120,
    countInStock: 15,
    features: ['6.7-inch display', '128GB storage', 'Triple camera system', 'All-day battery life']
  },
  {
    _id: '2',
    name: 'Laptop Pro',
    description: 'Powerful laptop for professionals and creative work.',
    price: 1499.99,
    category: 'Laptops',
    brand: 'ComputeTech',
    image: 'https://via.placeholder.com/500x500?text=Laptop',
    rating: 4.8,
    numReviews: 95,
    countInStock: 10,
    features: ['15-inch Retina display', '16GB RAM', '512GB SSD', 'Dedicated graphics card']
  },
  {
    _id: '3',
    name: 'Wireless Headphones',
    description: 'Premium noise-cancelling wireless headphones with long battery life.',
    price: 249.99,
    category: 'Audio',
    brand: 'SoundMaster',
    image: 'https://via.placeholder.com/500x500?text=Headphones',
    rating: 4.6,
    numReviews: 210,
    countInStock: 25,
    features: ['Active noise cancellation', '30-hour battery life', 'Premium sound quality', 'Comfortable design']
  },
  {
    _id: '4',
    name: 'Smart Watch',
    description: 'Feature-rich smartwatch with health monitoring and notifications.',
    price: 299.99,
    category: 'Wearables',
    brand: 'FitTech',
    image: 'https://via.placeholder.com/500x500?text=Smartwatch',
    rating: 4.3,
    numReviews: 78,
    countInStock: 18,
    features: ['Heart rate monitoring', 'GPS tracking', 'Water resistant', '7-day battery life']
  },
  {
    _id: '5',
    name: '4K Smart TV',
    description: 'Ultra HD Smart TV with vibrant colors and smart features.',
    price: 799.99,
    category: 'TVs',
    brand: 'ViewTech',
    image: 'https://via.placeholder.com/500x500?text=TV',
    rating: 4.7,
    numReviews: 65,
    countInStock: 8,
    features: ['55-inch 4K display', 'Smart TV functionality', 'HDR support', 'Multiple HDMI ports']
  },
  {
    _id: '6',
    name: 'Wireless Earbuds',
    description: 'Compact wireless earbuds with great sound quality and comfort.',
    price: 129.99,
    category: 'Audio',
    brand: 'SoundMaster',
    image: 'https://via.placeholder.com/500x500?text=Earbuds',
    rating: 4.4,
    numReviews: 182,
    countInStock: 30,
    features: ['True wireless design', '24-hour battery with case', 'Water resistant', 'Touch controls']
  }
];

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// API Routes
app.get('/api/products', (req, res) => {
  res.json(products);
});

app.get('/api/products/:id', (req, res) => {
  const product = products.find(p => p._id === req.params.id);
  if (product) {
    res.json(product);
  } else {
    res.status(404).json({ message: 'Product not found' });
  }
});

// Serve static assets if in production
if (process.env.NODE_ENV === 'production') {
  // Set static folder
  app.use(express.static('frontend'));

  app.get('*', (req, res) => {
    res.sendFile(path.resolve(__dirname, 'frontend', 'index.html'));
  });
}

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});