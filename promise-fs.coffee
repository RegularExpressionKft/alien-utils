Promise = require 'bluebird'
glob = require 'glob'
_ = require 'lodash'
fs = require 'fs'

# promiseFs = Promise.promisifyAll fs
# promiseFs.stat doesn't work

promisified = {}

methods = _.filter _.keysIn(fs), (name) ->
  _.isFunction(fs[name]) and _.isFunction(fs["#{name}Sync"])
methods.forEach (name) ->
  fs_method = fs[name]
  cb_idx = fs_method.length - 1
  promisified[name] = (args...) ->
    new Promise (resolve, reject) ->
      try
        args[cb_idx] = (error, results...) ->
          if error?
            reject error
          else
            resolve results...
        fs_method.apply fs, args
      catch error
        reject error

['createReadStream', 'createWriteStream'].forEach (name) ->
  promisified[name] = (path, options) ->
    new Promise (resolve, reject) ->
      try
        fs[name] path, options
          .once 'error', reject
          .once 'open', ->
            @removeListener 'error', reject
            resolve @
      catch error
        reject error

promisified.glob = (pattern, options) ->
  new Promise (resolve, reject) ->
    try
      glob pattern, options, (error, result) ->
        if error?
          reject error
        else
          resolve result
    catch error
      reject error

module.exports = promisified
