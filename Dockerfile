FROM gitea/gitea:1.21.5-rootless

# Install dependencies (tetap sebagai git user untuk rootless)
USER root
RUN apk add --no-cache curl jq postgresql-client bash

# Create necessary directories dengan permission yang tepat
RUN mkdir -p /var/lib/gitea/data \
    /var/lib/gitea/repositories \
    /var/lib/gitea/log \
    /var/lib/gitea/lfs \
    && chown -R git:git /var/lib/gitea

USER git

# Copy config files
COPY --chown=git:git app.ini /etc/gitea/app.ini
COPY --chown=git:git entrypoint.sh /entrypoint.sh

USER root
RUN chmod +x /entrypoint.sh && chmod 640 /etc/gitea/app.ini

USER git

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/api/healthz || exit 1

# Expose ports
EXPOSE 3000 2222

# Custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/gitea", "web"]
