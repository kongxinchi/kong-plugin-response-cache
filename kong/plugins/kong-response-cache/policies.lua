local redis = require "kong.plugins.kong-response-cache.rediscli"
local shm = ngx.shared.kong_response_cache
local Errors = require "kong.dao.errors"

return {
    ["local"] = {
        get = function(conf, key)
            if not shm then
                return nil, Errors.schema("ngx.shared.kong_response_cache has not exists")
            end

            local value, err = shm:get(key)
            if err then
                return nil, err
            end

            if value then
                local expiry = tonumber(string.sub(value, 1, 10))
                if expiry < os.time() then
                    value = nil
                else
                    return string.sub(value, 11), nil
                end
            else
                return nil, nil
            end
        end,
        set = function(conf, key, value, ttl)
            if not shm then
                return false, Errors.schema("ngx.shared.kong_response_cache has not exists")
            end

            local expiry = os.time() + ttl
            value = string.format("%10d%s", expiry, value)
            return shm:set(key, value)
        end
    },
    ["redis"] = {
        get = function(conf, key)
            local red = redis.new(conf.redis)
            local cached_value, err = red:exec(
                function(red)
                    return red:get(key)
                end
            )

            if cached_value == ngx.null then
                cached_value = nil
            end
            return cached_value, err
        end,
        set = function(conf, key, value, ttl)
            local red = redis.new(conf.redis)
            local res, err = red:exec(
                function(red)
                    return red:setex(key, ttl, value)
                end
            )
            if res == 'OK' then
                res = true
            end
            return res, err
        end
    }
}
