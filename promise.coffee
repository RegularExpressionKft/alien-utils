Promise = require 'bluebird'

module.exports =
  promiseFirst: (arr, processor) ->
    idx = 0
    processor = Promise.method processor
    iter = ->
      i = idx++
      if i < arr.length
        processor arr[i], i, arr
          .then (result) -> result ? iter()
      else
        Promise.resolve()
    iter()

  safePromise: (starter) ->
    new Promise (resolve, reject) ->
      live = true
      wrap = (f) -> ->
        if live
          live = false
          f.apply @, arguments
        else
          null
      starter wrap(resolve), wrap(reject)
