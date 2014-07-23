local escape_pattern, parse_content_disposition, build_url
do
  local _obj_0 = require("lapis.util")
  escape_pattern, parse_content_disposition, build_url = _obj_0.escape_pattern, _obj_0.parse_content_disposition, _obj_0.build_url
end

local flatten_params
flatten_params = function(t)
  local _tbl_0 = { }
  for k, v in pairs(t) do
    _tbl_0[k] = type(v) == "table" and v[#v] or v
  end
  return _tbl_0
end

local parse_url, parse_query
do
  pcall( function() 
      local util = require("leda.util")
      parse_url = util.parseUrl
      parse_query = util.parseQuery
 end)
end

local http
pcall(function()
    http = require 'leda.server.http'
end)


local request = {
  headers = function()
    return __leda.request:headers()
  end,
  cmd_mth = function()
    return __leda.request:method()
  end,
  cmd_url = function()
    return  __leda.request:url()
  end,
  body = function()
    return __leda.request:body()
  end,
  relpath = function(t)
    return t.parsed_url.path
  end,
  scheme = function(t)
    return t.parsed_url.scheme
  end,
  port = function(t)
    return t.parsed_url.port 
  end,
  srv = function()
    return t.parsed_url.host 
  end,
  remote_addr = function()
    return __leda.request:address()
  end,
  referer = function()
    return  ""
  end,
  parsed_url = function(t)
    local host = t.headers.host
    local parsed =  parse_url(t.cmd_url)
    if host then 
        local parsed_host = parse_url(host)
        parsed.host = parsed_host.host
        parsed.port = parsed_host.port
    end
    return parsed
  end,
  built_url = function(t)
    return build_url(t.parsed_url)
  end,
 
  params_post = function(t) 
    if (t.headers["content-type"] or ""):match(escape_pattern("application/x-www-form-urlencoded")) then
        return flatten_params(parse_query(t.body or ""))
    end
    
    return {}
  end,
  
  params_get = function(t)
    return flatten_params(t.parsed_url.params)
  end
}
local lazy_tbl
lazy_tbl = function(tbl, index)
  return setmetatable(tbl, {
    __index = function(self, key)
      local fn = index[key]
      if fn then
        do
          local res = fn(self)
          self[key] = res
          return res
        end
      end
    end
  })
end
local build_request
build_request = function(unlazy)
  if unlazy == nil then
    unlazy = false
  end
  do
    local t = lazy_tbl({ }, request)
    if unlazy then
      for k in pairs(request) do
        local _ = t[k]
      end
    end
    return t
  end
end
local build_response
build_response = function()
  return {
    req = build_request(),
    add_header = function(self, k, v)
      local old = self.headers[k]
      local _exp_0 = type(old)
      if "nil" == _exp_0 then
        self.headers[k] = v
      elseif "table" == _exp_0 then
        old[#old + 1] = v
        self.headers[k] = old
      else
        self.headers[k] = {
          old,
          v
        }
      end
    end,
    headers = {}
  }
end

local function request_callback(app, request, response)
    __leda.request = request
    __leda.response = response

    local res = build_response()
  
    app:dispatch(res.req, res)
    if res.status then
        response.status = res.status
    end
  
    if next(res.headers) then
        response.headers = res.headers
    end
  
    response.body = res.content or ""
    response:send()
end

local dispatch
dispatch = function(app)
    local config = require("lapis.config")
    local server = http(config.get().port, config.get().host or 'localhost')
    server.request = function(server, request, response) request_callback(app, request, response) end
end
return {
  build_request = build_request,
  build_response = build_response,
  dispatch = dispatch
}