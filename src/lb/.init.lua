local env = require "env"
local assign = require "assign"

local servers = {}
for server in string.gmatch(env["SERVERS"], "[^|]+") do
  table.insert(servers, server)
end

local state = { request_counter = 0 }

function OnHttpRequest()
  state.request_counter = (state.request_counter + 1) % 128

  local idx = (state.request_counter % #servers) + 1
  local url = servers[idx] .. EscapePath(GetPath())

  local status, headers, body =
      Fetch(url,
        {
          method = GetMethod(),
          headers = assign(GetHeaders(), {
            ['X-Forwarded-For'] = FormatIp(GetClientAddr())
          }),
          body = GetBody(),
        })

  if status then
    SetStatus(status)
    for k, v in pairs(headers) do
      if string.lower(k) ~= "content-length" and string.lower(k) ~= "date" and string.lower(k) ~= "server" then
        SetHeader(k, v)
      end
    end
    Write(body)
  else
    local err = headers
    Log(kLogError, "proxy failed %s" % { err })
    ServeError(503)
  end
end
