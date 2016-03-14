fs = require 'fs'

logger = require 'debug'

Resource = require('bcdn').Resource

exports = module.exports = class ResourceIndex extends Resource
  debug: logger 'ResourceIndex:debug'

  deserialize: (file, cb) ->
    @debug "load resource index from #{file}..."

    fs.readFile file, 'utf8', (err, data) =>
      throw "error occurs while reading resource index" if err?

      # parse indexes
      @pieces = (piece for piece in data.split '\n' when piece isnt '')
      cb()
