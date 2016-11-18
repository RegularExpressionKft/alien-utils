Promise = require 'bluebird'
pfs = require './promise-fs'

fileUtils =
  defaults:
    dirMode: 0o770
    fileMode: 0o660

  isEnoent: (error) ->
    error? and (error instanceof Error) and (error.code == 'ENOENT')
  isEexist: (error) ->
    error? and (error instanceof Error) and (error.code == 'EEXIST')

  promiseReadJson: (fn, options) ->
    pfs.readFile fn, options
       .then (data) -> JSON.parse data

  promiseWriteJson: (fn, json, options) ->
    try
      text = JSON.stringify(json, null, 2) + "\n"
      pfs.writeFile fn, text, options
    catch error
      Promise.reject error

module.exports = fileUtils
