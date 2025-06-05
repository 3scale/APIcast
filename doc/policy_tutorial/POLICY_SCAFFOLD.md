# Generate a policy scaffold
In the first part of the tutorial about APIcast policy development, you set up a development environment. Now you have a functioning development environment, you can start development of the APIcast policy. You will use the scaffolding utility provided by APIcast to generate a policy scaffold.

First, create a new git branch of the APIcast source cloned in the previous part. This is an optional step, but developing a new feature or changing code in general in a new branch is a good habit to get into. Create a new branch and start the development container.

```shell
$ git checkout -b policy-development-tutorial
Switched to a new branch 'policy-development-tutorial'
$ make development
```

To generate the scaffold of the policy, use the APIcast utility located in the bin/ directory of the development container.
In the development container, run the following command:

```shell
$ bin/apicast generate policy hello_world
```

where hello_world is the name of the policy.

```shell
bash-4.4$ bin/apicast generate policy hello_world
source: /home/centos/examples/scaffold/policy
destination: /home/centos

exists: spec
exists: spec/policy
created: spec/policy/hello_world
created: spec/policy/hello_world/hello_world_spec.lua
exists: t
created: t/apicast-policy-hello_world.t
exists: gateway
exists: gateway/src
exists: gateway/src/apicast
exists: gateway/src/apicast/policy
created: gateway/src/apicast/policy/hello_world
created: gateway/src/apicast/policy/hello_world/apicast-policy.json
created: gateway/src/apicast/policy/hello_world/init.lua
created: gateway/src/apicast/policy/hello_world/hello_world.lua
```

You will see from the output of the generate policy command, files have been created. These artefacts related to the policy, are located in three different directories:

* t/ – this directory contains all Nginx integration tests
* src/gateway/apicast/policy – this directory contains the source code and configuration schemas of all policies. Our policy resides in the subdirectory of hello_world
* spec/policy – this directory contains the unit tests of all policies. The unit tests for our policy resides in the subdirectory of hello_world

The policy scaffolding utility not only generates a scaffold for the policy, but also the files for a configuration schema, unit tests, and integration tests.

The source code of the policy in the directory src/gateway/apicast/policy/hello_world contains three files.

* init.lua: All policies contain this init.lua file. It contains 1 line importing (required in Lua) our policy. It should not be modified.
* aplicast-policy.json: The APIcast gateway is configured using a JSON document. Policies requiring configuration also use this JSON document. The apicast-policy.json file is a JSON schema file where configuration properties for the policy can be defined. The next section looks into configuration properties and this file in more detail.
```json
{
  "$schema": "http://apicast.io/policy-v1/schema",
  "name": "hello_world",
  "summary": "TODO: write policy summary",
  "description": [
      "TODO: Write policy description"
  ],
  "version": "builtin",
  "configuration": {
    "type": "object",
    "properties": { }
  }
}
```
* hello_world.lua: This is the actual source code of the policy, which at the moment does not contain much.
```lua
-- This is a hello_world description.
local policy = require('apicast.policy')
local _M = policy.new('hello_world')
local new = _M.new
--- Initialize a hello_world
-- @tparam[opt] table config Policy configuration.
function _M.new(config)
  local self = new(config)
  return self
end
return _M
```

The first two lines import the APIcast policy module and instantiate a new policy with hello_world as an argument. This returns a module and implements it using a Lua table. Lua is not an object oriented language, but tables, especially metatables, can mimic objects. The third line stores a reference to a function new, which is defined below. The new function takes a configuration variable as  an argument, but for now nothing happens with is. The new method returns itself. Finally, the module representing the policy is returned. This is done so other components importing this policy module retrieve the table and can invoke all functions and variables stored in the policy.
We won’t cover all the files in details here since we are going to touch these in upcoming series when we flesh out our policy with functionality.
As a final verification to check if everything is working, run the unit tests again.

```
bash-4.4$ make busted
```

You will see the number of successes in the unit test outcome will have increased by 2 after generating the scaffold for the policy.

In the next part you will create the implementation of the policy. This is described [here](POLICY_IMPLEMENTATION.md)
