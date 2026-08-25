# ── CIDR Report Server ───────────────────────────────────────────────────────
# Bakes reports into the image for portable, share-anywhere snapshots.
# For day-to-day use prefer docker-compose.yml (volume mount, no rebuild needed).
#
# Build:  docker build -t cidr-reports .
# Run:    docker run -p 8080:80 cidr-reports
# ─────────────────────────────────────────────────────────────────────────────
FROM nginx:alpine

LABEL org.opencontainers.image.title="CIDR Report Server" \
      org.opencontainers.image.description="nginx static server for CIDR inventory HTML reports"

# Remove default nginx config and content
RUN rm /etc/nginx/conf.d/default.conf \
    && rm -rf /usr/share/nginx/html/*

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy all HTML reports and index files
# (only *.html and *.json — skip .py, .csv, etc.)
COPY index.html          /usr/share/nginx/html/
COPY reports_index.json  /usr/share/nginx/html/
COPY *.html              /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
