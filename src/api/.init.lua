local env = require "env"
local map = require "map"

local db = require "db"
local repo = db.open(env["DB_CONNECTION_URL"])

local re = require "re"
-- POST /clientes/[id]/transacoes
-- GET /clientes/[id]/extrato
local reClientsPath = re.compile [[^/clientes/([0-9]+)/(transacoes|extrato)]]

local function info(...)
  print(...)
end

ERROR = {
  MISSING_OR_INVALID_PARAMS = 100,
  CLIENT_NOT_FOUND = 101,
  CLIENT_LIMIT_INSUFFICIENT = 102,
  UNKNOWN = 999,
}

local function transaction_create(client_id, tx)
  if not repo.select_client_exists(client_id) then
    return nil, ERROR.CLIENT_NOT_FOUND
  end

  local result = repo.insert_transaction(client_id, tx)
  if result == '' then
    return nil, ERROR.CLIENT_LIMIT_INSUFFICIENT
  end

  return result
end

local function client_statement(client_id)
  if not repo.select_client_exists(client_id) then
    return nil, ERROR.CLIENT_NOT_FOUND
  end

  local statement = repo.select_client_balance_with_transactions_latest10(client_id)
  if statement == nil then
    return nil, ERROR.UNKNOWN
  end

  return statement
end

HANDLERS = {
  POST = {
    transacoes = function(client_id)
      client_id = tonumber(client_id)
      local body = GetBody()
      local params = DecodeJson(body)

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
        info('transacoes', client_id, body, '=>', '{ error = ERROR.MISSING_OR_INVALID_PARAMS }')
        return
      end

      local result, err = transaction_create(client_id, body)

      if err == ERROR.CLIENT_NOT_FOUND then
        SetStatus(404)
        Write(EncodeJson({
          error = ERROR.CLIENT_NOT_FOUND
        }))
        print('transacoes', client_id, body, '=>', '{ error = ERROR.CLIENT_NOT_FOUND }')
        return
      elseif err == ERROR.CLIENT_LIMIT_INSUFFICIENT then
        SetStatus(422)
        Write(EncodeJson({
          error = ERROR.CLIENT_LIMIT_INSUFFICIENT
        }))
        info('transacoes', client_id, body, '=>', '{ error = ERROR.CLIENT_LIMIT_INSUFFICIENT }')
        return
      elseif err ~= nil then
        SetStatus(500)
        Write(EncodeJson({
          error = ERROR.UNKNOWN
        }))
        info('transacoes', client_id, body, '=>', '{ error = ERROR.UNKNOWN }')
        return
      end

      SetStatus(200)
      SetHeader('Content-Type', 'application/json')
      Write(result)
      info('transacoes', client_id, body, '=>', result)
    end,
  },
  GET = {
    extrato = function(client_id)
      client_id = tonumber(client_id)
      local statement, err = client_statement(client_id)

      if err == ERROR.CLIENT_NOT_FOUND then
        SetStatus(404)
        Write(EncodeJson({
          error = ERROR.CLIENT_NOT_FOUND
        }))
        info('extrato', client_id, '=>', '{ error = ERROR.CLIENT_NOT_FOUND }')
        return
      elseif err ~= nil then
        SetStatus(500)
        Write(EncodeJson({
          error = ERROR.UNKNOWN
        }))
        info('extrato', client_id, '=>', '{ error = ERROR.UNKNOWN }')
        return
      end

      SetStatus(200)
      SetHeader('Content-Type', 'application/json')
      Write(statement)
      info('extrato', client_id, '=>', statement)
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
