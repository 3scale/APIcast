--- APIcast source loader
-- Loading this module will add a new source code loaders to package.searchers.
-- The searcher is going to print deprecation warnings when apicast source is loaded
-- through old or non prefixed paths.
-- We can rename files and set up an alias here so we don't break customer's code and
-- print a deprecation warning.
-- Another searcher is going to look for policies with `.policy` suffix.
-- Policies can be packaged as `some_name/policy.lua` so the directory also contains the JSON spec.

local loadfile = loadfile
local sub = string.sub

local policy_loader = require 'apicast.policy_loader'

local map = {
  ['apicast'] = 'apicast.policy.apicast'
}

local function loader(name, path)
  local file, err = package.searchpath(name, path)

  if file then
    file, err = loadfile(file)
  end

  return file, err
end

--- Searcher has to return the loader or an error message.
local function policy_searcher(name)
  if sub(name, 1, 15) == 'apicast.policy.' then
    local mod = policy_loader:pcall(sub(name, 16), 'builtin')

    if mod then return function () return mod end end
  end
end

local function prefix_loader(name, path)
  local prefixed = 'apicast.' .. name
  local found, err = loader(prefixed, path)

  if not found then
    found = policy_searcher(prefixed)
  end

  if found then
    ngx.log(ngx.STDERR, 'DEPRECATION: when loading apicast code use correct prefix: require("', prefixed, '")')
  end

  return found or err
end

local function rename_loader(name, path)
  local new = map[name]
  local found, err = policy_searcher(new)

  if not found then
    found = loader(new, path)
  end

  if found then
    ngx.log(ngx.WARN, 'DEPRECATION: file renamed - change: require("', name, '")' ,' to: require("', new, '")')
  end

  return found or err
end

local function apicast_namespace(name)
  local path = package.path

  if not package.searchpath(name, path) then
    if map[name] then
      return rename_loader(name, path)
    else
      return prefix_loader(name, path)
    end
  end
end

table.insert(package.searchers, policy_searcher)
table.insert(package.searchers, apicast_namespace)
