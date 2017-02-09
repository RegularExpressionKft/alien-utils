Promise = require 'bluebird'
promise_exec = require './promise-exec'

promise_stdout = (cmdline, options) ->
  promise_exec arguments...
  .then (result) ->
    if result.stderr? and result.stderr isnt ''
      Promise.reject "stderr: #{result.stderr}"
    else
      result.stdout

module.exports = promise_stdout
