local count = 0
for i = 1, #arg do
  local path = arg[i]
  local chunk, err = loadfile(path)
  assert(chunk, (path or '') .. ': ' .. tostring(err))
  print('OK LUA: ' .. path)
  count = count + 1
end
print(('PASS: %d Lua files'):format(count))
