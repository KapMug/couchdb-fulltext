# couchdb-fulltext

This is a Docker image for CouchDB with full text search.

## Running

Building and running this image as a container is as simple as running these two commands:

```
docker build . -t couchdb:fulltext
docker run -p 5984:5984 couchdb:fulltext
```
