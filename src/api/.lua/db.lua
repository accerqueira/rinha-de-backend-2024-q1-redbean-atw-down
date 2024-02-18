local mod = {}

function mod.open(base_url)
  local function select_client_with_timestamp(client_id)
    local _, _, body =
        Fetch(base_url .. "/select_client_with_timestamp", EncodeJson({
          client_id = client_id
        }))
    return DecodeJson(body)
  end

  local function select_client_exists(client_id)
    local _, _, body =
        Fetch(base_url .. "/select_client_exists", EncodeJson({
          client_id = client_id
        }))
    return DecodeJson(body)
  end

  local function update_client_balance(client_id, value)
    local _, _, body =
        Fetch(base_url .. "/update_client_balance", EncodeJson({
          client_id = client_id,
          value = value,
        }))
    return DecodeJson(body)
  end

  local function insert_transaction(client_id, type, value, description)
    local _, _, body =
        Fetch(base_url .. "/insert_transaction", EncodeJson({
          client_id = client_id,
          type = type,
          value = value,
          description = description,
        }))
    return DecodeJson(body)
  end

  local function select_transactions_lastest10(client_id)
    local _, _, body =
        Fetch(base_url .. "/select_transactions_lastest10", EncodeJson({
          client_id = client_id,
        }))
    return DecodeJson(body)
  end

  return {
    select_client_exists = select_client_exists,
    select_client_with_timestamp = select_client_with_timestamp,
    update_client_balance = update_client_balance,
    insert_transaction = insert_transaction,
    select_transactions_lastest10 = select_transactions_lastest10,
  }
end

return mod
