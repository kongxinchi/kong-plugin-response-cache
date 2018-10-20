
return {
    no_consumer = true,
    fields = {
        redis = {
            type = "table",
            schema = {
                fields = {
                    host = {type = "string", required = true, default = '127.0.0.1'},
                    port = {type = "number", required = true, default = 6379},
                    password = {type = "string"},
                    timeout = {type = "number", required = true, default = 2000},
                    database = {type = "number", required = true, default = 0}
                }
            }
        },
        cache_param_keys = {
            required = true,
            type = "array",
            default = {}
        },
        ttl = {
            required = true,
            type = 'number',
            default = 3
        },
        policy = {
            type = "string",
            enum = {"local", "redis"},
            default = "local"
        }
        -- 填入时间戳的键名，获取缓存结果后会将这个键替换为当前时间
        --timestamp_key = {
        --    type = 'string',
        --    default = ''
        --}
    }
}