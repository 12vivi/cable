ARG CABLE_BASE_IMAGE=archlinux@sha256:345a872f6c95e082d4b8c050af637eebb57402c6e2177b411c3acf7df84eb33b
FROM ${CABLE_BASE_IMAGE}

ARG CABLE_BASE_IMAGE
ARG CABLE_RUNTIME_UID=1000
ARG CABLE_RUNTIME_GID=1000
ARG CABLE_ARCH_SNAPSHOT=2026/08/09
ARG CABLE_PYPI_INDEX_URL=https://mirrors.aliyun.com/pypi/simple
ARG CABLE_NPM_REGISTRY=https://registry.npmmirror.com

ENV HOME=/home/huashen \
    PATH=/opt/venv/bin:/home/huashen/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN printf '%s\n' \
        'CacheServer = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' \
        'CacheServer = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch' \
        "Server = https://archive.archlinux.org/repos/${CABLE_ARCH_SNAPSHOT}/\$repo/os/\$arch" \
        > /etc/pacman.d/mirrorlist \
    && pacman --disable-download-timeout -Syyu --noconfirm \
    && pacman --disable-download-timeout -S --noconfirm --needed \
        ca-certificates \
        curl \
        git \
        nodejs \
        npm \
        python \
        python-pip \
        util-linux \
        zsh \
    && pacman -Scc --noconfirm \
    && groupadd --gid "${CABLE_RUNTIME_GID}" huashen \
    && useradd \
        --uid "${CABLE_RUNTIME_UID}" \
        --gid "${CABLE_RUNTIME_GID}" \
        --create-home \
        --shell /usr/bin/zsh \
        huashen

WORKDIR /opt/cable/source

COPY docker/host-runtime/requirements.lock /tmp/requirements.lock
RUN python -m venv /opt/venv \
    && /opt/venv/bin/python -m pip install \
        --index-url "${CABLE_PYPI_INDEX_URL}" \
        --no-cache-dir --require-hashes -r /tmp/requirements.lock

ARG CABLE_SOURCE_COMMIT
ARG CABLE_SOURCE_TREE
ARG CABLE_SOURCE_ARCHIVE_SHA256
ARG CABLE_SOURCE_MANIFEST_SHA256
ARG CABLE_REQUIREMENTS_LOCK_SHA256
ARG CABLE_PACKAGE_LOCK_SHA256
COPY . /opt/cable/source
RUN test -n "${CABLE_SOURCE_COMMIT}" \
    && test -n "${CABLE_SOURCE_TREE}" \
    && test -n "${CABLE_SOURCE_ARCHIVE_SHA256}" \
    && test -n "${CABLE_SOURCE_MANIFEST_SHA256}" \
    && test "$(sha256sum .cable-source-manifest.json | cut -d' ' -f1)" = "${CABLE_SOURCE_MANIFEST_SHA256}" \
    && test "$(sha256sum docker/host-runtime/requirements.lock | cut -d' ' -f1)" = "${CABLE_REQUIREMENTS_LOCK_SHA256}" \
    && test "$(sha256sum package-lock.json | cut -d' ' -f1)" = "${CABLE_PACKAGE_LOCK_SHA256}" \
    && /opt/venv/bin/python docker/host-runtime/verify_release_source.py \
        --root /opt/cable/source \
        --manifest /opt/cable/source/.cable-source-manifest.json \
        --expected-commit "${CABLE_SOURCE_COMMIT}" \
        --expected-tree "${CABLE_SOURCE_TREE}" \
        --expected-archive-sha256 "${CABLE_SOURCE_ARCHIVE_SHA256}" \
    && /opt/venv/bin/python -c "import site; from pathlib import Path; Path(site.getsitepackages()[0], 'cable-sdk.pth').write_text('/opt/cable/source/sdk/python/src\n')" \
    && /opt/venv/bin/python -c "import cable_sdk; assert cable_sdk.__file__.startswith('/opt/cable/source/sdk/python/src/')" \
    && npm ci --ignore-scripts --registry "${CABLE_NPM_REGISTRY}" \
    && npm run build \
    && rm -rf node_modules /root/.npm \
    && PACMAN_DIGEST="$(pacman -Q | LC_ALL=C sort | sha256sum | cut -d' ' -f1)" \
    && PYTHON_VERSION="$(python --version | cut -d' ' -f2)" \
    && NODE_VERSION="$(node --version)" \
    && NPM_VERSION="$(npm --version)" \
    && printf '%s\n' \
        '{' \
        '  "schemaVersion": 2,' \
        "  \"sourceCommit\": \"${CABLE_SOURCE_COMMIT}\"," \
        "  \"sourceTree\": \"${CABLE_SOURCE_TREE}\"," \
        "  \"sourceArchiveSha256\": \"${CABLE_SOURCE_ARCHIVE_SHA256}\"," \
        "  \"sourceManifestSha256\": \"${CABLE_SOURCE_MANIFEST_SHA256}\"," \
        "  \"baseImage\": \"${CABLE_BASE_IMAGE}\"," \
        "  \"archSnapshot\": \"${CABLE_ARCH_SNAPSHOT}\"," \
        "  \"pypiIndexUrl\": \"${CABLE_PYPI_INDEX_URL}\"," \
        "  \"npmRegistry\": \"${CABLE_NPM_REGISTRY}\"," \
        "  \"pacmanDigest\": \"${PACMAN_DIGEST}\"," \
        "  \"requirementsLockSha256\": \"${CABLE_REQUIREMENTS_LOCK_SHA256}\"," \
        "  \"packageLockSha256\": \"${CABLE_PACKAGE_LOCK_SHA256}\"," \
        "  \"pythonVersion\": \"${PYTHON_VERSION}\"," \
        "  \"nodeVersion\": \"${NODE_VERSION}\"," \
        "  \"npmVersion\": \"${NPM_VERSION}\"" \
        '}' \
        > /opt/cable/runtime-info.json \
    && chown -R root:root /opt/cable \
    && chmod -R a-w /opt/cable

LABEL org.opencontainers.image.revision="${CABLE_SOURCE_COMMIT}"

USER huashen:huashen
ENTRYPOINT ["/opt/cable/source/docker/host-runtime/entrypoint.sh"]
CMD ["supervise"]
