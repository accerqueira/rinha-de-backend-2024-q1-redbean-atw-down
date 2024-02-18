local mod = {}

function mod.open(path, script)
  local sqlite3 = require "lsqlite3"
  local db = sqlite3.open(path)
  db:busy_timeout(1000)
  db:exec [[PRAGMA journal_mode=WAL]]
  db:exec [[PRAGMA synchronous=NORMAL]]

  if script ~= nil then
    db:exec(script)
  end

  local sql_select_client_with_timestamp_stmt = db:prepare [[
    SELECT *, strftime('%Y-%m-%dT%H:%M:%fZ', 'now') as timestamp
      FROM clients
      WHERE id = :client_id;
  ]]
  local sql_select_client_exists_stmt = db:prepare [[
    SELECT 1
      FROM clients
      WHERE id = :client_id;
  ]]
  local sql_select_transactions_lastest10_stmt = db:prepare [[
    SELECT *, strftime('%Y-%m-%dT%H:%M:%fZ', performed_at) as performed_at
      FROM transactions
      WHERE client_id = :client_id
      ORDER BY rowid DESC
      LIMIT 10;
  ]]
  local sql_insert_transaction_stmt = db:prepare [[
    INSERT INTO transactions (client_id, "type", value, description) VALUES (:client_id, :type, :value, :description);
  ]]
  local sql_update_client_balance_stmt = db:prepare [[
    UPDATE clients
      SET balance = (balance + :value)
      WHERE id = :client_id AND (balance + :value) >= (-"limit")
      RETURNING *;
  ]]

  local function select_client_with_timestamp(params)
    -- { client_id = client_id }
    local stmt = sql_select_client_with_timestamp_stmt
    stmt:bind_names(params)

    if stmt:step() ~= sqlite3.ROW then
      stmt:reset()
      return nil
    end

    local r = stmt:get_named_values()
    stmt:reset()
    return r
  end

  local function select_client_exists(params)
    -- { client_id = client_id }
    local stmt = sql_select_client_exists_stmt
    stmt:bind_names(params)

    local r = stmt:step() == sqlite3.ROW
    stmt:reset()
    return r
  end

  local function update_client_balance(params)
    -- { client_id = client_id, value = value }
    local stmt = sql_update_client_balance_stmt
    stmt:bind_names(params)

    if stmt:step() ~= sqlite3.ROW then
      stmt:reset()
      return nil
    end

    local r = stmt:get_named_values()
    stmt:reset()
    return r
  end

  local function insert_transaction(params)
    -- { client_id = client_id, type = type, value = value, description = description }
    local stmt = sql_insert_transaction_stmt
    stmt:bind_names(params)

    local r = stmt:step()
    stmt:reset()
    return r == sqlite3.DONE
  end

  local function select_transactions_lastest10(params)
    -- { client_id = client_id }
    local stmt = sql_select_transactions_lastest10_stmt
    stmt:bind_names(params)

    local r = {}
    for row in stmt:nrows() do
      table.insert(r, row)
    end
    stmt:reset()
    return r
  end

  return {
    executeScript = executeScript,
    select_client_exists = select_client_exists,
    select_client_with_timestamp = select_client_with_timestamp,
    update_client_balance = update_client_balance,
    insert_transaction = insert_transaction,
    select_transactions_lastest10 = select_transactions_lastest10,
  }
end

return mod
