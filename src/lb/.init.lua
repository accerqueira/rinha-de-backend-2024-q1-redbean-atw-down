local env = require "env"
local assign = require "assign"

local db = require "db"
local repo = db.open("db.sqlite3")

local servers = {}
for server in string.gmatch(env["SERVERS"], "[^|]+") do
  table.insert(servers, server)
end

function OnHttpRequest()
  local state = repo.get_updated_state() or { request_counter = math.random(1, #servers) }

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
      if string.lower(k) ~= "content-length" then
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
