local mod = {}

function mod.open(path)
  local sqlite3 = require "lsqlite3"
  local db = sqlite3.open(path)
  db:busy_timeout(1000)
  db:exec [[PRAGMA journal_mode=WAL]]
  db:exec [[PRAGMA synchronous=NORMAL]]
  db:exec [[
    CREATE TABLE state (
        request_counter INTEGER NOT NULL
    );
    INSERT INTO state (request_counter) VALUES (0);
  ]]

  local sql_get_updated_state_stmt = db:prepare [[
    UPDATE state
      SET request_counter = (request_counter + 1) % 128
      RETURNING *;
  ]]

  local function get_updated_state()
    local stmt = sql_get_updated_state_stmt

    if stmt:step() ~= sqlite3.ROW then
      stmt:reset()
      return nil
    end

    local r = stmt:get_named_values()
    stmt:reset()

    return r
  end

  return {
    get_updated_state = get_updated_state
  }
end

return mod
