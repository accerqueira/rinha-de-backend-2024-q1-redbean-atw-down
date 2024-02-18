local env = {}

local reEnvVar = re.compile [[^([^=]+)=(.*)]]

local function init()
  for _, v in ipairs(unix.environ()) do
    local _, key, value = reEnvVar:search(v)
    env[key] = value
  end
end

init()

return env
