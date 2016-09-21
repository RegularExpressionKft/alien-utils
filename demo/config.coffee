fs = require 'fs'

AlienConfig = require '../config'

# should be enough if config is in cwd
# config = AlienConfig
#   # whoIsStrongest: 'user'
#   commonObject:
#     user: 'user'

dir = try
    fs.statSync 'config'
    null
  catch error
    './demo'
config = AlienConfig
    # whoIsStrongest: 'user'
    commonObject:
      user: 'user'
  , dir

console.log 'config:', config
