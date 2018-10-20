#! /bin/bash
docker network create kong-net

docker stop kong-database

docker run -d --rm --name kong-database --network=kong-net -p 9042:9042 cassandra:3

sleep 30

docker run --rm \
    --network=kong-net \
    -e "KONG_DATABASE=cassandra" \
    -e "KONG_PG_HOST=kong-database" \
    -e "KONG_CASSANDRA_CONTACT_POINTS=kong-database" \
    kong:0.14.1-centos kong migrations up
