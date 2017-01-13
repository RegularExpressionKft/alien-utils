Promise = require 'bluebird'
pfs = require './promise-fs'
pu = require './promise'

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

  promiseReadBuffer: (fn, pos, len) ->
    buffer = Buffer.alloc len
    fd = null

    pfs.open fn, 'r'
       .then (_fd) ->
         fd = _fd
         pfs.read fd, buffer, 0, len, pos
       .catch (error) ->
         pfs.close fd
            .then -> Promise.reject error
       .then (bytes_read) ->
         if bytes_read is len
           buffer
         else
           buffer.slice 0, bytes_read

  promiseWriteBuffer: (fn, buffer, pos = 0, flags = 'r+', mode) ->
    fd = null

    pfs.open fn, flags, mode
       .then (_fd) ->
         fd = _fd
         pfs.write fd, buffer, 0, buffer.length, pos
       .catch (error) ->
         pfs.close fd
            .then -> Promise.reject error
       .then (bytes_written) ->
         pfs.close fd
            .return bytes_written

  chainStat: (paths, processor) ->
    processor ?= (path, stats) -> path
    pu.promiseFirst paths, (path, idx) ->
      pfs.stat path
         .then (stats) -> processor path, stats, idx
         .catchReturn isEnoent, null

module.exports = fileUtils
