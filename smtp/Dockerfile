FROM alpine
CMD [ "smtpd", "-d" ]
MAINTAINER RekGRpth
RUN set -eux; \
    apk update --no-cache; \
    apk upgrade --no-cache; \
    apk add --no-cache --virtual .build-deps \
        autoconf \
        automake \
        file \
        gawk \
        gcc \
        gettext-dev \
        git \
        libpq-dev \
        libtool \
        make \
        musl-dev \
        texinfo \
    ; \
    mkdir -p "${HOME}/src"; \
    cd "${HOME}/src"; \
    git clone -b master git://git.code.sf.net/p/gawkextlib/code.git; \
    cd "${HOME}/src/code/lib"; \
    autoreconf -vif; \
    ./configure; \
    make -j"$(nproc)" install; \
    cd "${HOME}/src/code/pgsql"; \
    autoreconf -vif; \
    ./configure --with-libpq="$(pg_config --includedir)"; \
    make -j"$(nproc)" install; \
    cd /; \
    apk add --no-cache --virtual .smtp-rundeps \
        busybox-extras \
        busybox-suid \
        ca-certificates \
        gawk \
        musl-locales \
        opensmtpd \
        shadow \
        tzdata \
        $(scanelf --needed --nobanner --format '%n#p' --recursive /usr/local | tr ',' '\n' | sort -u | while read -r lib; do test ! -e "/usr/local/lib/$lib" && echo "so:$lib"; done) \
    ; \
    find /usr/local/bin -type f -exec strip '{}' \;; \
    find /usr/local/lib -type f -name "*.so" -exec strip '{}' \;; \
    apk del --no-cache .build-deps; \
    find /usr -type f -name "*.a" -delete; \
    find /usr -type f -name "*.la" -delete; \
    rm -rf "${HOME}" /usr/share/doc /usr/share/man /usr/local/share/doc /usr/local/share/man; \
    echo done
ADD smtpd /etc/smtpd
