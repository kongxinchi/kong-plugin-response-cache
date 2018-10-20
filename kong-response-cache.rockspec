package = "kong-response-cache"
version = "1.0.0"

local pluginName = "kong-response-cache"

supported_platforms = {"linux", "macosx"}
source = {
  url = "git://github.com/kongxinchi/kong-plugin-response-cache",
  tag = "0.1.0"
}

description = {
  summary = "gateway kong lua plugin, high-performance response cache.",
  homepage = "https://github.com/kongxinchi/kong-plugin-response-cache",
  license = "MIT License"
}

dependencies = {
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.kong-response-cache.handler"] = "kong/plugins/kong-response-cache/handler.lua",
    ["kong.plugins.kong-response-cache.schema"] = "kong/plugins/kong-response-cache/schema.lua",
  }
}