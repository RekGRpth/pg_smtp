FROM postgres:alpine
MAINTAINER RekGRpth
RUN set -eux; \
    apk update --no-cache; \
    apk upgrade --no-cache; \
    apk add --no-cache --virtual .build-deps \
        clang \
        clang-dev \
        curl-dev \
        file \
        flex \
        gcc \
        git \
        krb5-dev \
        linux-headers \
        llvm \
        llvm-dev \
        make \
        musl-dev \
        util-linux-dev \
    ; \
    mkdir -p "${HOME}/src"; \
    cd "${HOME}/src"; \
    git clone -b master https://github.com/RekGRpth/pg_curl.git; \
    git clone -b master https://github.com/RekGRpth/pg_task.git; \
    cd "${HOME}"; \
    find "${HOME}/src" -maxdepth 1 -mindepth 1 -type d | sort -u | while read -r NAME; do echo "$NAME" && cd "$NAME" && make -j"$(nproc)" USE_PGXS=1 install || exit 1; done; \
    cd /; \
    apk add --no-cache --virtual .postgresql-rundeps \
        bash \
        busybox-extras \
        busybox-suid \
        ca-certificates \
        musl-locales \
        shadow \
        su-exec \
        tzdata \
        $(scanelf --needed --nobanner --format '%n#p' --recursive /usr/local | tr ',' '\n' | grep -v -e perl -e python -e tcl | sort -u | while read -r lib; do test ! -e "/usr/local/lib/$lib" && echo "so:$lib"; done) \
    ; \
    find /usr/local/bin -type f -exec strip '{}' \;; \
    find /usr/local/lib -type f -name "*.so" -exec strip '{}' \;; \
    apk del --no-cache .build-deps; \
    find /usr -type f -name "*.la" -delete; \
    rm -rf "${HOME}" /usr/share/doc /usr/share/man /usr/local/share/doc /usr/local/share/man; \
    echo done
