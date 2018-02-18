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

# Acquire CouchDB source code
RUN cd /usr/src && mkdir couchdb \
 && git clone --branch $COUCHDB_VERSION https://github.com/apache/couchdb \
 && cd couchdb \
 # Replace before configure
 && sed -i '/DepDescs = \[/a %% My custom deps\n{dreyfus,          "dreyfus",          "master"},\n' rebar.config.script \
 && sed -i '/MakeDep = fun/a \    ({AppName, RepoName, Version}) when AppName == dreyfus ->\n        Url = "https:\/\/github.com\/cloudant-labs\/" ++ RepoName ++ ".git",\n        {AppName, ".*", {git, Url, Version}};' rebar.config.script \
 && ./configure --disable-fauxton --disable-docs \
 && sed -i "/{plugins, \[/a \    dreyfus_epi," rel/apps/couch_epi.config \
 && sed -i '/{rel, "couchdb", "2.1.1", \[/a \        %% custom\n        dreyfus,' rel/reltool.config \
 && sed -i '/{app, b64url, \[{incl_cond, include}\]},/i \    {app, dreyfus, [{incl_cond, include}]},' rel/reltool.config \
 && curl https://raw.githubusercontent.com/cloudant/couchdb/c323f194328822385aa1bb2ab15b927cc604c4b7/share/server/dreyfus.js > share/server/dreyfus.js \
 && sed -i '/JsFiles = \[/a \               "share/server/dreyfus.js",' support/build_js.escript \
 && sed -i '/CoffeeFiles = \[/a \                   "share/server/dreyfus.js",' support/build_js.escript \
 && sed -i '/sandbox.start =/a \    sandbox.index = Dreyfus.index;' share/server/loop.js \
 && sed -i '/var line, cmd, cmdkey, dispatch = {/a \    "index_doc": Dreyfus.indexDoc' share/server/loop.js \
 && sed -i 's/;admin = mysecretpassword/admin = admin/g' rel/overlay/etc/local.ini \
 && printf "\n[dreyfus]\nname = {{clouseau_name}}\n" >> rel/overlay/etc/local.ini \
 && printf "\n[dreyfus]\nname = {{clouseau_name}}\n" >> rel/overlay/etc/default.ini \
 && sed -i '/"cluster_port": cluster_port,/a \            "clouseau_name": "clouseau%d@127.0.0.1" % (idx+1),' dev/run \
 && make \
 # Cleanup build detritus
 && apt-get purge -y --auto-remove $buildDeps \
 && rm -rf /var/lib/apt/lists/* \
 && chown -R couchdb:couchdb /usr/src/couchdb

WORKDIR /usr/src

# Install Clouseau
RUN apt-get update -y && apt-get install -y --no-install-recommends maven \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/cloudant-labs/clouseau \
    && cd clouseau \
    && mvn clean install -DskipTests

# Install HAproxy & supervisor
RUN apt-get update -y && apt-get install -y --no-install-recommends Haproxy supervisor \
    && cp /usr/src/couchdb/rel/haproxy.cfg /etc/haproxy/haproxy.cfg
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 5984 15984 25984 35984
CMD ["/usr/bin/supervisord"]
