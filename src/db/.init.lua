-- local dump = require "dump"
local env = require "env"
local re = require "re"
local reClientsPath = re.compile [[^/([^/]+)$]]

local db = require "db"
local repo = db.open("db.sqlite3", env["DB_INIT_SCRIPT"])

function OnHttpRequest()
  local _, query = reClientsPath:search(GetPath())
  local params = DecodeJson(GetBody())

  local result = repo[query](params)

  SetStatus(200)
  Write(EncodeJson(result))
end
