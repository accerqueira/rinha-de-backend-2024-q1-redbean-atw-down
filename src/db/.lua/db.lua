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

  local sql_select_client_balance_with_transactions_latest10_stmt = db:prepare [[
	  SELECT json_object(
		  'saldo', json_object(
			  'total', saldo,
			  'limite', limite,
			  'data_extrato', strftime('%Y-%m-%dT%H:%M:%fZ')
		  ),
		  'ultimas_transacoes', json(ultimas_transacoes)
	  ) FROM clientes WHERE id = :client_id;
  ]]

  local sql_insert_transaction_stmt = db:prepare [[
	  UPDATE clientes
		  SET saldo=saldo + (
			  SELECT CASE WHEN tipo == 'd' THEN -valor ELSE valor END as valor FROM (
				  SELECT json_extract(value, '$.tipo') tipo, json_extract(value, '$.valor') valor FROM json_each('[' || :tx || ']')
			  )
		  ), ultimas_transacoes=(
			  SELECT json_remove(json_group_array(json(value)), '$[10]') txs FROM (
				  SELECT id, value FROM (
					  SELECT json_insert(json_group_array(json(value)), '$[#]', json_set(:tx, '$.realizada_em', strftime('%Y-%m-%dT%H:%M:%fZ'))) txs FROM (
						  SELECT txs.value FROM clientes c, json_each(c.ultimas_transacoes) txs WHERE c.id=:client_id ORDER BY key DESC
					  )
				  ) temp, json_each(temp.txs) ORDER BY key DESC
			  )
		  ) WHERE id=:client_id AND (saldo + (
			  SELECT CASE WHEN tipo == 'd' THEN -valor ELSE valor END as valor FROM (
				  SELECT json_extract(value, '$.tipo') tipo, json_extract(value, '$.valor') valor FROM json_each('[' || :tx || ']')
			  )
		  )) >= -limite RETURNING json_object('saldo', saldo, 'limite', limite);
  ]]


  local function select_client_exists(params)
    -- { client_id = client_id }
    local stmt = sql_select_client_exists_stmt
    stmt:bind_names(params)

    local r = stmt:step() == sqlite3.ROW
    stmt:reset()
    return r
  end

  local function select_client_balance_with_transactions_latest10(params)
    -- { client_id = client_id }
    local stmt = sql_select_client_balance_with_transactions_latest10_stmt
    stmt:bind_names(params)

    if stmt:step() ~= sqlite3.ROW then
      stmt:reset()
      return nil
    end

    local r = stmt:get_value(0)
    stmt:reset()
    return r
  end

  local function insert_transaction(params)
    -- { client_id = client_id, tx = tx }
    local stmt = sql_insert_transaction_stmt
    stmt:bind_names(params)

    if stmt:step() ~= sqlite3.ROW then
      stmt:reset()
      return nil
    end

    local r = stmt:get_value(0)
    stmt:reset()
    return r
  end

  return {
    select_client_exists = select_client_exists,
    select_client_balance_with_transactions_latest10 = select_client_balance_with_transactions_latest10,
    insert_transaction = insert_transaction,
  }
end

return mod
