local env = require "env"
local map = require "map"

local db = require "db"
local repo = db.open(env["DB_CONNECTION_URL"])

local re = require "re"
-- POST /clientes/[id]/transacoes
-- GET /clientes/[id]/extrato
local reClientsPath = re.compile [[^/clientes/([0-9]+)/(transacoes|extrato)]]


ERROR = {
  MISSING_OR_INVALID_PARAMS = 100,
  CLIENT_NOT_FOUND = 101,
  CLIENT_LIMIT_INSUFFICIENT = 102,
  UNKNOWN = 999,
}

local function transaction_create(client_id, type, value, description)
  if not repo.select_client_exists(client_id) then
    return nil, ERROR.CLIENT_NOT_FOUND
  end

  local value_with_sign = value
  if type == 'd' then value_with_sign = -value end
  local client = repo.update_client_balance(client_id, value_with_sign)
  if not client then
    return nil, ERROR.CLIENT_LIMIT_INSUFFICIENT
  end

  if not repo.insert_transaction(client_id, type, value, description) then
    return nil, ERROR.UNKNOWN
  end

  return client
end

local function client_statement(client_id)
  local client = repo.select_client_with_timestamp(client_id)
  if client == nil then
    return nil, nil
  end

  local transactions_latest10 = repo.select_transactions_lastest10(client_id)

  return client, transactions_latest10
end

HANDLERS = {
  POST = {
    transacoes = function(client_id)
      local params = DecodeJson(GetBody())

      if not (
            (params.tipo == 'c' or params.tipo == 'd')
            and math.type(params.valor) == 'integer'
            and type(params.descricao) == 'string'
            and params.descricao:len() >= 1
            and params.descricao:len() <= 10
          ) then
        SetStatus(422)
        Write(EncodeJson({
          error = ERROR.MISSING_OR_INVALID_PARAMS
        }))
        return
      end

      local client, err = transaction_create(client_id, params.tipo, params.valor, params.descricao)

      if client == nil then
        if err == ERROR.CLIENT_NOT_FOUND then
          SetStatus(404)
          Write(EncodeJson({
            error = ERROR.CLIENT_NOT_FOUND
          }))
        elseif err == ERROR.CLIENT_LIMIT_INSUFFICIENT then
          SetStatus(422)
          Write(EncodeJson({
            error = ERROR.CLIENT_LIMIT_INSUFFICIENT
          }))
        else
          SetStatus(500)
          Write(EncodeJson({
            error = ERROR.UNKNOWN
          }))
        end
        return
      end

      SetStatus(200)
      SetHeader('Content-Type', 'application/json')
      Write(EncodeJson({
        limite = client.limit,
        saldo = client.balance,
      }))
    end,
  },
  GET = {
    extrato = function(client_id)
      local client, transactions_latest10 = client_statement(client_id)

      if client == nil then
        SetStatus(404)
        Write(EncodeJson({
          error = ERROR.CLIENT_NOT_FOUND
        }))
        return
      end

      SetStatus(200)
      SetHeader('Content-Type', 'application/json')
      Write(EncodeJson({
        saldo = {
          total = client.balance,
          data_extrato = client.timestamp,
          limite = client.limit,
        },
        ultimas_transacoes = map(transactions_latest10, function(tx)
          return {
            valor = tx.value,
            tipo = tx.type,
            descricao = tx.description,
            realizada_em = tx.performed_at,
          }
        end)
      }))
    end,
  }
}


function OnHttpRequest()
  _, client_id, operation = reClientsPath:search(GetPath())

  local method = GetMethod()

  local handler = HANDLERS[method][operation]

  if handler then
    handler(client_id)
  else
    SetStatus(404)
    Write(EncodeJson({
      error = ERROR.UNKNOWN
    }))
  end
end
