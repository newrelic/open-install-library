# Dockerfile
#base image
FROM node:18

# Create app directory
WORKDIR /app

# Install app dependencies
COPY . /app

# Bundle app source
RUN npm install

# Expose the port the app runs on
EXPOSE 3000

# Command to run the application
CMD ["node", "app.js"]



      
      
      
      
      