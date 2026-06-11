# Multi-stage Dockerfile to build Flutter web and serve with nginx
FROM ghcr.io/cirruslabs/flutter:stable AS builder

# Create a non-root user to avoid running flutter as root
RUN addgroup -S flutter && adduser -S -G flutter flutter

WORKDIR /app
# Copy files as the non-root user
COPY --chown=flutter:flutter . .

USER flutter
ENV PUB_CACHE=/home/flutter/.pub-cache

# Install dependencies and build web as non-root
RUN flutter pub get
RUN flutter build web --release

FROM nginx:stable-alpine

# Copy built web content into nginx
COPY --from=builder /app/build/web /usr/share/nginx/html

# Expose standard HTTP port; map host port as desired (e.g. docker run -p 8080:80)
EXPOSE 80

# Start nginx (default config serves /usr/share/nginx/html)
CMD ["nginx", "-g", "daemon off;"]
