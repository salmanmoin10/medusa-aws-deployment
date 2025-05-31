FROM node:18-alpine3.18

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies with exact versions
RUN npm install --production && npm cache clean --force

# Copy application code
COPY . .

# Expose port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:9000/health || exit 1

# Start the application
CMD ["npm", "start"]
