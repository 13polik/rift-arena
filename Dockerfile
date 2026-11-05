# RIFT ARENA - online dedicated server (headless Godot, WebSocket).
# The hosting platform terminates TLS, so clients connect with wss://<host> and the server listens on $PORT.
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates wget unzip libfontconfig1 \
 && rm -rf /var/lib/apt/lists/* \
 && wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -O /tmp/godot.zip \
 && unzip -q /tmp/godot.zip -d /opt \
 && mv "/opt/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
 && chmod +x /usr/local/bin/godot \
 && rm /tmp/godot.zip

WORKDIR /app
COPY . .
# Build the import cache / global class list once at image build time (fast cold starts).
RUN godot --headless --path /app --import || true

ENV PORT=10000
EXPOSE 10000
CMD ["godot", "--headless", "--path", "/app", "--", "server", "ws"]
