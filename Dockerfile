#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG IMAGE_VERSION=buster
FROM debian:$IMAGE_VERSION
LABEL maintainer="Nils Nolde<nils@gis-ops.com>"

# Reset ARG for version
ARG IMAGE_VERSION
ENV  DEBIAN_FRONTEND noninteractive
RUN  dpkg-divert --local --rename --add /sbin/initctl

RUN apt-get -y update && \
    apt-get -y install \
      gnupg2 \
      wget \
      ca-certificates \
      rpl \
      pwgen \
      gdal-bin \
      netcat && \
    rm -rf /var/lib/apt/lists/*

RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ ${IMAGE_VERSION}-pgdg main" > /etc/apt/sources.list.d/postgresql.list' && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc -O- | apt-key add -

#-------------Application Specific Stuff ----------------------------------------------------

# We add postgis as well to prevent build errors (that we dont see on local builds)
# on docker hub e.g.
# The following packages have unmet dependencies:
RUN apt-get update && \
    apt-get install -y \
      postgresql-client-12 \
      postgresql-common \
      postgresql-12 \
      postgresql-11-ogr-fdw && \
    rm -rf /var/lib/apt/lists/*

# Open port 5432 so linked containers can see them
EXPOSE 5432

# Optimizer specific stuff
ENV PGROUTING_VERSION master

WORKDIR /usr/local/src/optimizer

COPY . .

RUN apt-get update && \
    apt-get install -y -q \
        build-essential \
        cmake \
        perl \
        wget \
        git-all \
        libboost-graph-dev \
        libpq-dev \
        postgresql-12-postgis-3 \
        postgresql-server-dev-12 && \
  cd /usr/local/src && \
  # wget https://github.com/gis-ops/pgrouting/archive/v3.0.0-rc1-dn-fix1.tar.gz && \
  # tar xvf v3.0.0-rc1-dn-fix1.tar.gz && \
  # cd pgrouting-3.0.0-rc1-dn-fix1 && \
  git clone https://github.com/gis-ops/pgrouting.git && \
  cd pgrouting && \
  git checkout develop && \
  mkdir build && \
  cd build && \
  cmake .. && \
  make && \
  make install && \
  cd /usr/local/src/optimizer && \
  mkdir build && \
  cd build && \
  cmake .. && \
  make && \
  make install && \
  cd ../../ && \
  rm -rf ./* && \
  apt purge -y \
    build-essential \
    cmake \
    perl \
    wget \
    libpq-dev \
    postgresql-server-dev-11 && \
  apt-get install -y \
    postgresql-12-postgis-3-scripts \
    libboost-graph1.67.0 \
    libboost-program-options1.67.0 && \
  apt autoremove -y && \
  rm -rf /var/lib/apt/lists/*

# Run any additional tasks here that are too tedious to put in
# this dockerfile directly.
COPY docker_scripts/env-data.sh /env-data.sh
COPY docker_scripts/docker-entrypoint.sh /docker-entrypoint.sh
COPY docker_scripts/setup.sh /setup.sh
COPY docker_scripts/ /
RUN chmod +x /setup.sh /docker-entrypoint.sh && \
    /bin/bash /setup.sh

COPY locale.gen /etc/locale.gen
RUN /usr/sbin/locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
RUN update-locale ${LANG}

ENTRYPOINT /docker-entrypoint.sh

