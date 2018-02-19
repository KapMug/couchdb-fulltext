FROM debian:jessie
ENV COUCHDB_VERSION 2.1.1

# Add CouchDB user account
RUN groupadd -r couchdb && useradd -d /usr/src/couchdb -g couchdb couchdb

# Install dependencies
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    erlang-nox \
    erlang-reltool \
    haproxy \
    libicu52 \
    libmozjs185-1.0 \
    openssl \
  && rm -rf /var/lib/apt/lists/*

RUN buildDeps=' \
    apt-transport-https \
    gcc \
    g++ \
    erlang-dev \
    libcurl4-openssl-dev \
    libicu-dev \
    libmozjs185-dev \
    make \
  ' \
 && apt-get update -y -qq && apt-get install -y --no-install-recommends $buildDeps

RUN apt-get update -y && apt-get install -y --no-install-recommends git python3 \
    && ln -s /usr/bin/python3 /usr/bin/python

# Build CouchDB
COPY search-diff-$COUCHDB_VERSION.patch /usr/src
RUN cd /usr/src && mkdir couchdb \
 && git clone --branch $COUCHDB_VERSION https://github.com/apache/couchdb \
 && cd couchdb \
 && git apply < /usr/src/search-diff-$COUCHDB_VERSION.patch \
 && rm -f /usr/src/search-diff-$COUCHDB_VERSION.patch \
 && ./configure --disable-fauxton --disable-docs \
 && make \
 # Cleanup build detritus
 && apt-get purge -y --auto-remove $buildDeps \
 && rm -rf /var/lib/apt/lists/* \
 && chown -R couchdb:couchdb /usr/src/couchdb

# Expose to the outside
RUN sed -i 's/;*bind_address = 127.0.0.1/bind_address = 0.0.0.0/' /usr/src/couchdb/rel/overlay/etc/local.ini \
  && sed -i 's/;*admin = mysecretpassword/admin = admin/g' /usr/src/couchdb/rel/overlay/etc/local.ini

# Install Clouseau
RUN apt-get update -y && apt-get install -y --no-install-recommends maven \
  && rm -rf /var/lib/apt/lists/* \
  && cd /usr/src \
  && git clone https://github.com/cloudant-labs/clouseau \
  && cd clouseau \
  && mvn clean install -DskipTests

# Install HAproxy & supervisor
RUN apt-get update -y && apt-get install -y --no-install-recommends Haproxy supervisor \
  && cp /usr/src/couchdb/rel/haproxy.cfg /etc/haproxy/haproxy.cfg
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

WORKDIR /usr/src/couchdb

EXPOSE 5984 15984 25984 35984
CMD ["/usr/bin/supervisord"]
