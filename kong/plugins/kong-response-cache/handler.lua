local policies = require "kong.plugins.kong-response-cache.policies"
local cjson_decode = require("cjson").decode
local cjson_encode = require("cjson").encode

local BasePlugin = require "kong.plugins.base_plugin"
local CacheHandler = BasePlugin:extend()
CacheHandler.PRIORITY = 804
CacheHandler.VERSION = "1.0.0"

local function json_decode(json)
    if json then
        local status, res = pcall(cjson_decode, json)
        if status then
            return res
        end
    end
end

local function json_encode(table)
    if table then
        local status, res = pcall(cjson_encode, table)
        if status then
            return res
        end
    end
end

-- 反序列化数据
local function unserialize(cached_value)
    local header_len = tonumber(string.sub(cached_value, 1, 10))
    local value = {
        headers = json_decode(string.sub(cached_value, 11, 11 + header_len - 1)),
        body = string.sub(cached_value, 11 + header_len)
    }
    return value
end

-- 序列化数据
local function serialize(value)
    local header_str = json_encode(value['headers'])
    local header_len = string.len(header_str)
    local res = string.format("%10d%s%s", header_len, header_str, value['body'])
    return res
end

-- 根据不同的method获取参数列表
local function get_request_params()
    local method = kong.request.get_method()
    if method == "GET" then
        return kong.request.get_query()
    elseif method == "POST" then
        return kong.request.get_body()
    end
    return {}
end

-- 构建缓存键, 取出在filter_param_keys中的参数，构建缓存键
local function build_cache_key(uri, params, filter_param_keys)
    local param_str = ""

    for _, pk in ipairs(filter_param_keys) do
        local pv = params[pk]
        local type_pv = type(pv)

        if param_str ~= "" and type_pv ~= "nil" then
            param_str = param_str .. ":"
        end

        if type_pv == "string" or type_pv == "number" then
            param_str = param_str .. pk .. "=" .. pv
        elseif type_pv == "boolean" then
            param_str = param_str .. pk .. "=" .. string.format("%s", pv)
        elseif type_pv == "table" then
            param_str = param_str .. pk .. "=" .. json_encode(pv)
        end
    end

    if string.len(param_str) > 32 then
        param_str = ngx.md5(param_str)
    end

    return uri .. ":" .. param_str
end

-- 写入缓存
local function timer_cache_set(premature, conf, key, value, ttl)
    local cache_value = serialize(value)
    local res, err = policies[conf.policy].set(conf, key, cache_value, ttl)

    if err then
        kong.log.err(string.format(
            "fail on cache set key:%s, policy:%s, err:%s",
            key,
            conf.policy,
            err
        ))
    end
end

-- 替换返回结果中的timestamp字段
--local function replace_timestamp(time_key, body)
--    return string.gsub(body, "(\""..time_key.."\":%s?)(%d%d%d%d%d%d%d%d%d%d)([,}])", "%1"..os.time().."%3")
--end

function CacheHandler:new()
    CacheHandler.super.new(self, "kong-response-cache")
end

function CacheHandler:access(conf)
    CacheHandler.super.access(self)

    local uri = kong.request.get_path()
    local params = get_request_params()
    local cache_key = build_cache_key(uri, params, conf.cache_param_keys)

    local cached_value, err = policies[conf.policy].get(conf, cache_key)

    if err then
        kong.log.err(string.format(
                "fail on cache get key:%s, policy:%s, err:%s",
                cache_key,
                conf.policy,
                err
        ))
        return
    end

    if cached_value then
        local value = unserialize(cached_value)
        if value then
            local body = value.body

            --if conf.timestamp_key and conf.timestamp_key ~= "" then
            --    body = replace_timestamp(conf.timestamp_key, body)
            --end

            kong.response.exit(200, body, value.headers)
        end
    end

    kong.ctx.plugin.cache_key = cache_key
end

function CacheHandler:header_filter(conf)
    CacheHandler.super.header_filter(self)
end

function CacheHandler:body_filter(conf)
    CacheHandler.super.body_filter(self)

    -- 不缓存非200状态码的响应
    local status = kong.service.response.get_status()
    if status ~= 200 then
        return
    end

    local cache_key = kong.ctx.plugin.cache_key
    if not cache_key then
        return
    end

    local chunk = ngx.arg[1]
    local eof = ngx.arg[2]

    kong.ctx.plugin.body = (kong.ctx.plugin.body or "") .. (chunk or "")

    if eof then
        local value = {
            headers = kong.service.response.get_headers(),
            body = kong.ctx.plugin.body
        }
        value["headers"]["X-Kong-Cache-Time"] = os.time()

        ngx.timer.at(0, timer_cache_set, conf, cache_key, value, conf.ttl)
    end
end

return CacheHandler