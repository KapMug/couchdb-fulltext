RUN apt-get update && \
    apt-get install -y git curl build-essential erlang libicu-dev libmozjs-24-dev libcurl4-openssl-dev && \
    git clone https://github.com/apache/couchdb.git && \
    cd couchdb

RUN sed -i '/DepDescs = \[/a %% My custom deps\n{dreyfus,          "dreyfus",          "master"},\n' rebar.config.script && \
    sed -i '/MakeDep = fun/a \    ({AppName, RepoName, Version}) when AppName == dreyfus ->\n        Url = "https:\/\/github.com\/cloudant-labs\/" ++ RepoName ++ ".git",\n        {AppName, ".*", {git, Url, Version}};' rebar.config.script

RUN ./configure
