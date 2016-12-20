Promise = require 'bluebird'
pfs = require './promise-fs'

isEnoent = (error) ->
  error? and (error instanceof Error) and (error.code == 'ENOENT')
isEexist = (error) ->
  error? and (error instanceof Error) and (error.code == 'EEXIST')

fileUtils =
  defaults:
    dirMode: 0o770
    fileMode: 0o660

  isEnoent: isEnoent
  isEexist: isEexist

  promiseReadJson: (fn, options) ->
    pfs.readFile fn, options
       .then (data) -> JSON.parse data

  promiseWriteJson: (fn, json, options) ->
    try
      text = JSON.stringify(json, null, 2) + "\n"
      pfs.writeFile fn, text, options
    catch error
      Promise.reject error

  chainStat: (paths, processor) ->
    processor ?= (path, stats) -> path

    i = 0
    next = ->
      if i < paths.length
        if (path = paths[i++])?
          pfs.stat path
             .then (stats) ->
               Promise.resolve processor path, stats
                      .then (result) -> result ? next()
             .catch isEnoent, next
        else
          next()
      else
        Promise.resolve()

    iter()

module.exports = fileUtils
