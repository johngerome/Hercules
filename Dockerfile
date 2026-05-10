# Stage 1: Build Hercules
FROM debian:bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    make \
    default-libmysqlclient-dev \
    libpcre3-dev \
    zlib1g-dev \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

RUN ./configure CFLAGS="-DBUILDBOT" \
    && make clean \
    && make sql

# Stage 2: Runtime
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libmariadb3 \
    libpcre3 \
    zlib1g \
    ca-certificates \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/hercules

COPY --from=builder /build/login-server /opt/hercules/
COPY --from=builder /build/char-server /opt/hercules/
COPY --from=builder /build/map-server /opt/hercules/
COPY --from=builder /build/api-server /opt/hercules/

COPY --from=builder /build/conf/ /opt/hercules/conf/
COPY --from=builder /build/db/ /opt/hercules/db/
COPY --from=builder /build/npc/ /opt/hercules/npc/
COPY --from=builder /build/doc/ /opt/hercules/doc/
COPY --from=builder /build/maps/ /opt/hercules/maps/
COPY --from=builder /build/cache/ /opt/hercules/cache/

RUN mkdir -p /opt/hercules/log /opt/hercules/save

COPY docker-entrypoint.sh /opt/hercules/
RUN chmod +x /opt/hercules/docker-entrypoint.sh

WORKDIR /opt/hercules

ENV SERVICE=login-server

ENTRYPOINT ["/opt/hercules/docker-entrypoint.sh"]
