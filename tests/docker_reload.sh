#! /bin/bash

docker stop kong-response-cache
docker run -d --rm --name kong-response-cache \
    --network=kong-net \
    -e "KONG_DATABASE=cassandra" \
    -e "KONG_PG_HOST=kong-database" \
    -e "KONG_CASSANDRA_CONTACT_POINTS=kong-database" \
    -e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
    -e "KONG_LUA_PACKAGE_PATH=/opt/kong_plugins/?.lua;;" \
    -e "KONG_PLUGINS=kong-response-cache" \
    -e "KONG_LOG_LEVEL=info" \
    -v /Users/konglo/coding/kong-plugin-response-cache/kong/:/opt/kong_plugins/kong/ \
    -v /Users/konglo/coding/kong-plugin-response-cache/logs/:/usr/local/kong/logs/ \
    -v /Users/konglo/coding/kong-plugin-response-cache/tests/nginx-kong.conf:/usr/local/kong/nginx-kong.conf:ro \
    -p 8000:8000 \
    -p 8443:8443 \
    -p 8001:8001 \
    -p 8444:8444 \
    kong:0.14.1-centos

sleep 1

curl -XDELETE http://127.0.0.1:8001/apis/foo

curl -i -XPOST http://localhost:8001/apis/ \
    --data 'name=foo' --data 'upstream_url=http://10.2.0.215:19000/foo' --data 'uris=/foo'

curl -i -XPOST http://localhost:8001/apis/foo/plugins \
    --data 'name=kong-response-cache' \
    --data 'config.redis.host=10.2.0.215' \
    --data 'config.redis.port=6379' \
    --data 'config.cache_param_keys=arg1,arg2' \
    --data 'config.ttl=5' \
    --data 'config.policy=local'