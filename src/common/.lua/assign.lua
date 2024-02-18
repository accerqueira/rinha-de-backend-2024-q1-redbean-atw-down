local function assign(target, source)
  for k, v in pairs(source) do
    target[k] = v
  end
  return target
end

return assign
