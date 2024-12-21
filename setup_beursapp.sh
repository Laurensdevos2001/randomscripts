#!/bin/bash

# Exit on error
set -e

# Variables
# FRONTEND_REPO_URL: De URL van de GitHub repository van de frontend
FRONTEND_REPO_URL="<your-frontend-repo-url>"
# BACKEND_REPO_URL: De URL van de GitHub repository van de backend
BACKEND_REPO_URL="<your-backend-repo-url>"
# FRONTEND_PATH: De locatie waar de frontend bestanden worden opgeslagen na de build
FRONTEND_PATH="/var/www/frontend"
# BACKEND_PATH: De locatie waar de backend code wordt geplaatst
BACKEND_PATH="/home/$USER/backend"
# FRONTEND_PORT: De poort waarop de frontend toegankelijk is (standaard 80 voor HTTP)
FRONTEND_PORT=80
# BACKEND_PORT: De poort waarop de backend draait
BACKEND_PORT=3000
# LOCAL_IP: Het lokale IP-adres van de Linux-machine
LOCAL_IP=$(hostname -I | awk '{print $1}')
# DB_NAME: De naam van de database die gebruikt wordt door de applicatie
DB_NAME="myapp"
# DB_USER: De gebruikersnaam voor toegang tot de database
DB_USER="myappuser"
# DB_PASSWORD: Het wachtwoord voor de databasegebruiker
DB_PASSWORD="mypassword"

# Update and install necessary software
echo "Updating system and installing required software..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y nodejs npm nginx postgresql postgresql-contrib git

# Configure PostgreSQL
echo "Configuring PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# Backend setup
echo "Cloning and setting up backend..."
if [ -d "$BACKEND_PATH" ]; then
    echo "Backend path already exists. Pulling latest changes..."
    cd "$BACKEND_PATH"
    git pull
else
    git clone "$BACKEND_REPO_URL" "$BACKEND_PATH"
    cd "$BACKEND_PATH"
fi
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
echo "Cloning and setting up frontend..."
if [ -d "$FRONTEND_PATH" ]; then
    echo "Frontend path already exists. Pulling latest changes..."
    cd "$FRONTEND_PATH"
    git pull
else
    git clone "$FRONTEND_REPO_URL" "$FRONTEND_PATH"
    cd "$FRONTEND_PATH"
fi
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
