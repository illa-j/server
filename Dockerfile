FROM python:3.11

RUN groupadd -r freetak && useradd -m -r -g freetak freetak
RUN mkdir -p /opt/fts ; chown -R freetak:freetak /opt/fts ; chmod 775 /opt/fts ; chmod a+w /var/log

# Install gosu for dropping privileges in entrypoint
RUN apt-get update && apt-get install -y --no-install-recommends gosu && rm -rf /var/lib/apt/lists/*

ENV FTS_DATA_PATH="/opt/fts/"

WORKDIR /home/freetak/
COPY --chown=freetak:freetak --chmod=774 README.md pyproject.toml docker-run.sh docker-entrypoint.sh ./
COPY --chown=freetak:freetak --chmod=774 FreeTAKServer/ ./FreeTAKServer/

# Install sitecustomize.py monkey-patch for opentelemetry BatchSpanProcessor
COPY --chmod=644 sitecustomize.py /usr/local/lib/python3.11/site-packages/sitecustomize.py

ENV PATH="/home/freetak/.local/bin:$PATH"
RUN pip install --upgrade pip ; pip install setuptools wheel poetry ; pip install --force-reinstall "ruamel.yaml<0.18"
RUN pip install --no-build-isolation --editable .
# Install UI separately (its pinned deps conflict with FTS — we already have compatible versions)
RUN pip install --no-deps FreeTAKServer_UI==2.2
RUN pip install Flask-Migrate Flask-WTF Mako SQLAlchemy-Utils alembic

EXPOSE 8080 8087 8089 8443 19023

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/')" || exit 1

ENTRYPOINT ["/home/freetak/docker-entrypoint.sh"]
