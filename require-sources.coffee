glob = require 'glob'
path = require 'path'

module.exports = (opts) ->
  dirname = opts.dirname
  modules = {}

  files = glob.sync "#{dirname}/**/*.{coffee,js}"
  files.forEach (file) =>
    basename = file.replace /(?<=\w)\.\w+$/, ''
    modules[path.parse(basename).base] ?= require "#{basename}"
  modules
