FROM postgres:14
ARG NONINTERACTIVE=y
ADD \
    helpers/up.sh \
    helpers/add_gosu.sh \
    helpers/system_detect.sh \
    helpers/add_frep.sh \
    helpers/add_confd.sh \
    helpers/add_dockerize.sh \
    helpers/add_forego.sh \
    helpers/add_opt_pkgs.sh \
    helpers/add_remco.sh \
    helpers/setup_locales.sh \
    helpers/cops_pkgmgr_install.sh \
    helpers/*_up.sh \
    helpers/*_clean.sh \
    rootfs/ \
    packages/*packages*.txt \
    ${EXTRA_FILES_LIST} \
    /tmp/corpusopssteroids/
RUN cd /tmp/corpusopssteroids \
    && export PATH=$(pwd):$PATH \
    && _cops_SYSTEM=$(./system_detect.sh) \
    && cat ${_cops_SYSTEM}_packages*.txt > packages.txt \
    && cat ${_cops_SYSTEM}_optional_packages*.txt optional_packages*.txt > optional_packages.txt \
    && ./up.sh \
    && apt-get clean -y \
    && cd / && rm -rf /tmp/corpusopssteroids /var/cache/apk/* /var/lib/apt/lists/* \
    && rm -rf /var/lib/apt/lists/*
MAINTAINER Mike Dillon <mike@appropriate.io>

ENV POSTGIS_MAJOR 3
ENV POSTGIS_VERSION 3.4.2+dfsg-1.pgdg110+1

RUN apt-get update \
      && apt-cache showpkg postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
      && if ! ( : \
      && apt-get install -y --no-install-recommends \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR=$POSTGIS_VERSION \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts=$POSTGIS_VERSION \
           postgis=$POSTGIS_VERSION; );then  \
           : support older versions \
      && apt-get install -y --no-install-recommends \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts;fi \
      && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/postgis.sh
COPY ./update-postgis.sh /usr/local/bin

LABEL com.github.corpusops.docker-images-commit="$DOCKER_IMAGES_COMMIT"
ARG DOCKER_IMAGES_COMMIT=master
