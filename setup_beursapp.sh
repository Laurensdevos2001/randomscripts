#!/bin/bash

# Exit on error
set -e

# Variables
FRONTEND_PATH="/var/www/frontend"
BACKEND_PATH="/home/$USER/backend"
FRONTEND_PORT=80
BACKEND_PORT=3000
LOCAL_IP=$(hostname -I | awk '{print $1}')
DB_NAME="myapp"
DB_USER="myappuser"
DB_PASSWORD="mypassword"

# Update and install necessary software
echo "Updating system and installing required software..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y nodejs npm nginx postgresql postgresql-contrib

# Configure PostgreSQL
echo "Configuring PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# Backend setup
echo "Setting up backend..."
mkdir -p "$BACKEND_PATH"
# Placeholder for backend code - replace with your repository clone or copy
# git clone <your-backend-repo-url> "$BACKEND_PATH"
cd "$BACKEND_PATH"
npm install

# Create backend .env file
cat <<EOF > "$BACKEND_PATH/.env"
PORT=$BACKEND_PORT
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@localhost/$DB_NAME
EOF

# Start backend with PM2
echo "Starting backend..."
sudo npm install -g pm2
pm2 start "npm start" --name "backend" -- start
pm2 save

# Frontend setup
echo "Setting up frontend..."
mkdir -p "$FRONTEND_PATH"
# Placeholder for frontend code - replace with your repository clone or copy
# git clone <your-frontend-repo-url> "$FRONTEND_PATH"
cd "$FRONTEND_PATH"
npm install
npm run build

# Copy frontend build to NGINX root
sudo rm -rf /var/www/html/*
sudo cp -r build/* /var/www/html/

# Configure NGINX for frontend
echo "Configuring NGINX..."
cat <<EOF | sudo tee /etc/nginx/sites-available/default
server {
    listen $FRONTEND_PORT;
    server_name $LOCAL_IP;

    location / {
        root /var/www/html;
        index index.html index.htm;
    }

    location /api/ {
        proxy_pass http://localhost:$BACKEND_PORT/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Restart NGINX
echo "Restarting NGINX..."
sudo systemctl restart nginx
sudo ufw allow 'Nginx Full'

# Final output
echo "Setup complete!"
echo "Frontend available at: http://$LOCAL_IP"
echo "Backend API available at: http://$LOCAL_IP:$BACKEND_PORT"
echo "Database configured with user '$DB_USER' and database '$DB_NAME'"
