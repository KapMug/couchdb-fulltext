FROM debian:jessie
ENV COUCHDB_VERSION=2.1.1 \
    MAVEN_VERSION=3.2.5

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
    git \
    python3 \
    supervisor \
  && rm -rf /var/lib/apt/lists/*

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

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

# Install JDK 6 & Maven
RUN JAVA_BIN=ibm-java-x86_64-sdk-6.0-16.50.bin \
  && curl https://s3.amazonaws.com/kapmug-devops/$JAVA_BIN -o $JAVA_BIN \
  && chmod +x $JAVA_BIN \
  && ln -s /lib/x86_64-linux-gnu/libc.so.6 /lib/libc.so.6 \
  && printf "USER_INSTALL_DIR=/opt/java\nLICENSE_ACCEPTED=TRUE" > installer.properties \
  && ./$JAVA_BIN -i silent -f installer.properties \
  && rm -f $JAVA_BIN \
  && update-alternatives --install /usr/bin/java java /opt/java/bin/java 100 \
  && update-alternatives --install /usr/bin/javac javac /opt/java/bin/javac 100 \
  && curl -fsSL http://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar xzf - -C /usr/share \
  && mv /usr/share/apache-maven-$MAVEN_VERSION /usr/share/maven \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

# Install Clouseau
RUN cd /usr/src \
  && git clone https://github.com/cloudant-labs/clouseau \
  && cd clouseau \
  && mvn clean install -DskipTests

WORKDIR /usr/src/couchdb

EXPOSE 5984 15984 25984 35984
CMD ["/usr/bin/supervisord"]
