# Stage 1: Build the React app
FROM node:20 AS build

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json first (for caching)
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the source code
COPY . .

# Pass SonarCloud credentials as build args
ARG SONAR_TOKEN
ARG SONAR_HOST_URL=https://sonarcloud.io
ENV SONAR_TOKEN=$SONAR_TOKEN
ENV SONAR_HOST_URL=$SONAR_HOST_URL

# Run tests to generate coverage
RUN npm test -- --coverage

# Build production files
RUN npm run build

# Run SonarCloud scan (uses your sonar-project.properties)
RUN npx sonar-scanner -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.token=$SONAR_TOKEN

# Stage 2: Serve with Nginx
FROM nginx:stable-alpine

# Copy build output from Stage 1 to Nginx html folder
COPY --from=build /app/build /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
