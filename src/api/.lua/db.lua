local mod = {}

function mod.open(base_url)
  local function select_client_exists(client_id)
    return client_id >= 1 and client_id <= 5
  end

  local function select_client_balance_with_transactions_latest10(client_id)
    local _, _, body =
        Fetch(base_url .. "/select_client_balance_with_transactions_latest10", EncodeJson({
          client_id = client_id
        }))
    return body
  end

  local function insert_transaction(client_id, tx)
    local _, _, body =
        Fetch(base_url .. "/insert_transaction", EncodeJson({
          client_id = client_id,
          tx = tx,
        }))
    return body
  end

  return {
    select_client_exists = select_client_exists,
    select_client_balance_with_transactions_latest10 = select_client_balance_with_transactions_latest10,
    insert_transaction = insert_transaction,
  }
end

return mod
