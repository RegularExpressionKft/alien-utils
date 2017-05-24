Promise = require 'bluebird'
child_process = require 'child_process'

promise_exec = (cmdline, options) ->
  new Promise (resolve, reject) ->
    child_process.exec cmdline, options, (error, stdout, stderr) ->
      if error?
        error.stdout = stdout if stdout?
        error.stderr = stderr if stderr?
        reject error
      else
        resolve
          stdout: stdout
          stderr: stderr

module.exports = promise_exec
