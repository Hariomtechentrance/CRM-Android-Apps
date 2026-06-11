# Multi-stage Dockerfile to build Flutter web and serve with nginx
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app
COPY . .

RUN git config --global --add safe.directory /sdks/flutter && \
    flutter create . --platforms web && \
    flutter pub get
RUN flutter build web --release

FROM nginx:stable-alpine

# Copy built web content into nginx
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY start-nginx.sh /usr/local/bin/start-nginx.sh
RUN chmod +x /usr/local/bin/start-nginx.sh

EXPOSE 80

CMD ["/usr/local/bin/start-nginx.sh"]
