FROM corpusops/postgis-bare:11-2.5 as builder
MAINTAINER kiorky <kiorky@cryptelium.net>
RUN bash -euxc ': \
    && apt-get update -qq \
    && apt-get install -y --force-yes build-essential cmake \
               devscripts equivs lsb-release \
               dbconfig-common python-twisted-web daemon'
RUN bash -euc ': \
    && apt-get install -y --force-yes \
        cmake                \
        libboost-thread-dev  \
        libboost-graph-dev   \
        libcgal-dev          \
        python-sphinx        \
        graphviz             \
        texlive              \
        texlive-font-utils   \
        texlive-latex-extra  \
        ghostscript          \
        postgresql-server-dev-all \
    '
ENV PGROUTING_REPO=https://salsa.debian.org/debian-gis-team/pgrouting.git
RUN bash -euxc ': \
    && git clone $PGROUTING_REPO /usr/src/pgrouting'
WORKDIR /usr/src/pgrouting
ENV PG_MAJOR=11
ENV POSTGRES_MAJOR=11
ENV POSTGIS_MAJOR=2.5
ENV PGROUTING_MAJOR=2.4
ENV PGROUTING_VERSION=2.4.2-1
ENV PGROUTING_DEBIAN_VERSION=debian/2.4.2-1
ARG MAKEOPTS=-j4
RUN bash -euxc ': \
    && git reset --hard $PGROUTING_DEBIAN_VERSION \
    && sed -i -r \
         -e "s/postgresql-[0-9]+-postgis,/postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR,/g" \
         -e "s/postgresql-[0-9]+-/postgresql-$PG_MAJOR-/g" \
         -e "s/postgresql-[0-9]+-(pgrouting-scripts)/postgresql-$PG_MAJOR-\1/g" \
         -e "s/postgresql-PGVERSION-postgis,/postgresql-PGVERSION-postgis-$POSTGIS_MAJOR, postgresql-PGVERSION-postgis-$POSTGIS_MAJOR-scripts,/g" \
        debian/control* \
    && echo $PG_MAJOR > debian/pgversions \
    && pg_buildext updatecontrol \
    && cat debian/control \
    && mk-build-deps -t "apt-get --no-install-recommends -y --force-yes" -ir debian/control'
RUN bash -euxc ': \
    && debuild -i -us -uc -b'

FROM corpusops/postgis-bare:11-2.5
MAINTAINER kiorky <kiorky@cryptelium.net>
ENV PGROUTING_MAJOR 2.4
ENV PGROUTING_VERSION 2.4.2-1
COPY --from=builder /usr/src/*deb /tmp/
COPY ./initdb-pgrouting.sh /docker-entrypoint-initdb.d/routing.sh
RUN bash -euxc ': \
    && ls /tmp/*deb \
    && apt-get update \
    && apt install -y --no-install-recommends \
        $( ls /tmp/postgresql-$PG_MAJOR-pgrouting*deb -1 | grep -v dbg ) \
    && mkdir -p /docker-entrypoint-initdb.d \
    && rm -rvf /var/lib/apt/lists/* /tmp/*deb'
LABEL com.github.corpusops.docker-images-commit="$DOCKER_IMAGES_COMMIT"
ARG DOCKER_IMAGES_COMMIT=master
