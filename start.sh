#!/bin/bash

# Start Couchdb, then wait for "Time to hack!"
# Then start cloueau.

couchdb/dev/run --admin=admin:admin --nodes=1
mvn scala:run -f clouseau/pom.xml -Dlauncher=clouseau1
