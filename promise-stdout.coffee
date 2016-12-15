Promise = require 'bluebird'
child_process = require 'child_process'

promise_stdout = (cmdline, options) ->
  new Promise (resolve, reject) ->
    child_process.exec cmdline, options, (error, stdout, stderr) ->
      if error?
        reject error
      else if stderr? and stderr isnt ''
        reject "stderr: #{stderr}"
      else
        resolve stdout
    null

module.exports = promise_stdout
