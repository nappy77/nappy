# TechStore - Electronics E-commerce Website

A modern, responsive e-commerce website for electronics and tech gadgets built with React, Express, and Node.js.

## Features

- **Responsive Design**: Works seamlessly on desktop, tablet, and mobile devices
- **Dark/Light Mode**: Toggle between dark and light themes
- **Product Catalog**: Browse products with filtering and search functionality
- **User Authentication**: Register, login, and manage user profiles
- **Shopping Cart**: Add, remove, and update product quantities
- **Checkout Process**: Complete purchase with shipping and payment information
- **Order Management**: View order history and details
- **RESTful API**: Backend API for product data and user management

## Tech Stack

### Frontend
- React.js
- React Router for navigation
- Context API for state management
- CSS for styling (no UI libraries)
- React Icons for icons

### Backend
- Node.js
- Express.js
- MongoDB (configured but using mock data for demo)
- JWT for authentication

## Getting Started

### Prerequisites
- Node.js (v14 or higher)
- npm or yarn

### Installation

1. Clone the repository
   ```
   git clone https://github.com/yourusername/techstore.git
   cd techstore
   ```

2. Install backend dependencies
   ```
   npm install
   ```

3. Install frontend dependencies
   ```
   cd frontend
   npm install
   ```

4. Start the development server
   ```
   # From the root directory
   npm run dev
   ```

5. Open your browser and navigate to `http://localhost:3000`

## Project Structure

```
├── frontend/                # React frontend
│   ├── public/              # Public assets
│   ├── src/                 # Source files
│   │   ├── components/      # Reusable components
│   │   ├── pages/           # Page components
│   │   ├── App.jsx          # Main App component
│   │   └── index.js         # Entry point
│   └── package.json         # Frontend dependencies
├── server.js               # Express server
└── package.json            # Backend dependencies
```

## API Endpoints

- `GET /api/products` - Get all products
- `GET /api/products/:id` - Get a single product by ID

## Deployment

This application can be deployed to platforms like Heroku, Vercel, or Netlify.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Placeholder images from [Placeholder.com](https://placeholder.com)
- Icons from [React Icons](https://react-icons.github.io/react-icons/)