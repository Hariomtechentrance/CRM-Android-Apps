# Multi-stage Dockerfile to build Flutter web and serve with nginx
FROM ghcr.io/cirruslabs/flutter:stable AS builder

# Create a non-root user in a portable way (supports Debian/Alpine images)
RUN set -eux; \
	if command -v groupadd >/dev/null 2>&1; then \
		groupadd -r flutter || true; \
	else \
		addgroup -S flutter || true; \
	fi; \
	if command -v useradd >/dev/null 2>&1; then \
		useradd -r -g flutter -m -d /home/flutter -s /sbin/nologin flutter || true; \
	else \
		adduser -D -H -G flutter -h /home/flutter -s /sbin/nologin flutter || true; \
	fi; \
	mkdir -p /home/flutter || true; \
	chown -R flutter:flutter /home/flutter || true

WORKDIR /app
# Copy files as root then set ownership so the following RUN commands can switch to the user
COPY . .
RUN chown -R flutter:flutter /app || true

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
