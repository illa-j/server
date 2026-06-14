FROM python:3.11

RUN groupadd -r freetak && useradd -m -r -g freetak freetak
RUN mkdir -p /opt/fts ; chown -R freetak:freetak /opt/fts ; chmod 775 /opt/fts ; chmod a+w /var/log

ENV FTS_DATA_PATH="/opt/fts/"

WORKDIR /home/freetak/
COPY --chown=freetak:freetak --chmod=774 README.md pyproject.toml docker-run.sh ./
COPY --chown=freetak:freetak --chmod=774 FreeTAKServer/ ./FreeTAKServer/

ENV PATH="/home/freetak/.local/bin:$PATH"
RUN pip install --upgrade pip ; pip install setuptools wheel poetry ; pip install --force-reinstall "ruamel.yaml<0.18"
RUN pip install --no-build-isolation --editable .

EXPOSE 8080 8087 8089 8443

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/')" || exit 1

USER freetak

CMD [ "/home/freetak/docker-run.sh" ]
