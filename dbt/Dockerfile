#checkov:skip=CKV_DOCKER_2: No healthcheck required
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-alpine@sha256:236173eb74001afe2f60862de935b74fcbd00adfca247b2c27051a70a6a39a2d

ARG BUILD_DATE
ARG VERSION
ARG REVISION

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.title="region-20-dbt-core" \
      org.opencontainers.image.description="dbt-core transformation layer for Region 20 ESC"

COPY --from=ghcr.io/astral-sh/uv:0.9.27 /uv /bin/uv

ENV DBT_PROFILES_DIR=/home/dbt/.dbt \
    DBT_SEND_ANONYMOUS_USAGE_STATS=false

COPY pyproject.toml uv.lock /tmp/project/

RUN cd /tmp/project \
    && uv export --frozen --only-group dbt --no-emit-project -o /tmp/requirements.txt \
    && uv pip install --system --no-cache -r /tmp/requirements.txt \
    && rm -rf /tmp/project /tmp/requirements.txt

RUN addgroup -g 1001 dbt \
    && adduser -u 1001 -G dbt -s /bin/sh -D dbt

WORKDIR /home/dbt

COPY --chown=dbt:dbt dbt/profiles.yml .dbt/profiles.yml
COPY --chown=dbt:dbt dbt/r20_esc/ project/

USER dbt

WORKDIR /home/dbt/project

CMD ["dbt", "debug"]
