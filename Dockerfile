# syntax=docker/dockerfile:1

# ──────────────────────────────────────────────────────────────────────────────
# Stage: kotlin-ls-builder — build Kotlin Language Server from source
# ──────────────────────────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS kotlin-ls-builder

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git gnupg

RUN curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | \
      gpg --dearmor -o /usr/share/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" \
      > /etc/apt/sources.list.d/adoptium.list

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      temurin-11-jdk \
      temurin-21-jdk

ENV JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-${TARGETARCH}
ENV PATH=${JAVA_HOME}/bin:${PATH}

RUN --mount=type=cache,target=/root/.gradle \
    git clone --depth 1 https://github.com/fwcd/kotlin-language-server.git /kotlin-ls && \
    cd /kotlin-ls && \
    ./gradlew :server:installDist --no-daemon

# ──────────────────────────────────────────────────────────────────────────────
# Stage: runtime
# ──────────────────────────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS runtime

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# ──────────────────────────────────────────────────────────────────────────────
# Core system packages + language runtimes
# ──────────────────────────────────────────────────────────────────────────────
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl wget git openssh-client less unzip jq gnupg \
      python3 python3-pip python3-venv \
      clang clangd \
      php-cli

# ──────────────────────────────────────────────────────────────────────────────
# Node.js (from official nodesource — gives us latest LTS)
# ──────────────────────────────────────────────────────────────────────────────
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs

# ──────────────────────────────────────────────────────────────────────────────
# Bun (official install script)
# ──────────────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://bun.sh/install | bash && \
    ln -sf /root/.bun/bin/bun /usr/local/bin/bun && \
    ln -sf /root/.bun/bin/bun /usr/local/bin/bunx

# ──────────────────────────────────────────────────────────────────────────────
# Go (official tarball)
# ──────────────────────────────────────────────────────────────────────────────
RUN GO_VERSION=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1) && \
    curl -fSL "https://go.dev/dl/${GO_VERSION}.linux-${TARGETARCH}.tar.gz" -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz
ENV PATH=/usr/local/go/bin:${PATH}

# ──────────────────────────────────────────────────────────────────────────────
# JDK — all versions via Adoptium Temurin
# Default JAVA_HOME set to 21 (broad Gradle/Kotlin/Java compat)
# ──────────────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | \
      gpg --dearmor -o /usr/share/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" \
      > /etc/apt/sources.list.d/adoptium.list

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      temurin-8-jdk \
      temurin-11-jdk \
      temurin-17-jdk \
      temurin-21-jdk \
      temurin-25-jdk
ENV JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-${TARGETARCH}
ENV PATH=${JAVA_HOME}/bin:${PATH}

# ──────────────────────────────────────────────────────────────────────────────
# Kotlin (official GitHub release)
# ──────────────────────────────────────────────────────────────────────────────
RUN KOTLIN_TAG=$(curl -fsSL https://api.github.com/repos/JetBrains/kotlin/releases/latest | jq -r '.tag_name') && \
    KOTLIN_VERSION=${KOTLIN_TAG#v} && \
    curl -fSL "https://github.com/JetBrains/kotlin/releases/download/${KOTLIN_TAG}/kotlin-compiler-${KOTLIN_VERSION}.zip" \
      -o /tmp/kotlin.zip && \
    unzip -oq /tmp/kotlin.zip -d /opt && \
    ln -s /opt/kotlinc/bin/kotlin /usr/local/bin/kotlin && \
    ln -s /opt/kotlinc/bin/kotlinc /usr/local/bin/kotlinc && \
    rm /tmp/kotlin.zip

# ──────────────────────────────────────────────────────────────────────────────
# Cloudflared
# ──────────────────────────────────────────────────────────────────────────────
RUN curl -fSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${TARGETARCH}.deb" \
      -o /tmp/cloudflared.deb && \
    dpkg -i /tmp/cloudflared.deb && \
    rm /tmp/cloudflared.deb

ENV NODE_ENV=production

# Create openchamber user (UID/GID 1000)
RUN useradd -m -u 1000 -U -s /bin/bash openchamber && \
    mkdir -p /home/openchamber/go && \
    chown openchamber:openchamber /home/openchamber/go

# ──────────────────────────────────────────────────────────────────────────────
# Switch to openchamber user — everything below runs as non-root
# ──────────────────────────────────────────────────────────────────────────────
USER openchamber

ENV NPM_CONFIG_PREFIX=/home/openchamber/.npm-global
ENV GOPATH=/home/openchamber/go
ENV PATH=/home/openchamber/.local/bin:${NPM_CONFIG_PREFIX}/bin:${GOPATH}/bin:${PATH}

# ──────────────────────────────────────────────────────────────────────────────
# npm-based tools: openchamber + opencode + LSP servers + JS package managers
# ──────────────────────────────────────────────────────────────────────────────
RUN --mount=type=cache,target=/home/openchamber/.npm,uid=1000,gid=1000 \
    npm config set prefix /home/openchamber/.npm-global && \
    mkdir -p /home/openchamber/.npm-global \
      /home/openchamber/.local/bin \
      /home/openchamber/.config \
      /home/openchamber/.ssh && \
    npm install -g \
      @openchamber/web \
      opencode-ai \
      pnpm \
      yarn \
      typescript typescript-language-server \
      pyright \
      intelephense \
      eslint \
      oxlint \
      yaml-language-server \
      @astrojs/language-server \
      svelte-language-server \
      @vue/language-server \
      @prisma/language-server

# ──────────────────────────────────────────────────────────────────────────────
# Go LSP — gopls
# ──────────────────────────────────────────────────────────────────────────────
RUN --mount=type=cache,target=/home/openchamber/go/pkg/mod,uid=1000,gid=1000 \
    --mount=type=cache,target=/home/openchamber/go/pkg/sumdb,uid=1000,gid=1000 \
    --mount=type=cache,target=/home/openchamber/.cache/go-build,uid=1000,gid=1000 \
    mkdir -p /home/openchamber/go/bin && \
    go install golang.org/x/tools/gopls@latest

# ──────────────────────────────────────────────────────────────────────────────
# Kotlin Language Server (pre-built distribution from builder stage)
# ──────────────────────────────────────────────────────────────────────────────
COPY --from=kotlin-ls-builder --chown=openchamber:openchamber \
    /kotlin-ls/server/build/install/server \
    /home/openchamber/kotlin-ls/server/build/install/server

RUN ln -s /home/openchamber/kotlin-ls/server/build/install/server/bin/kotlin-language-server \
      /home/openchamber/.local/bin/kotlin-language-server

WORKDIR /home/openchamber

COPY --chmod=755 docker-entrypoint.sh /app/openchamber-entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["/app/openchamber-entrypoint.sh"]