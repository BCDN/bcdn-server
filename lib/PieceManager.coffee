fs = require 'fs'

logger = require 'debug'

exports = module.exports = class PieceManager
  debug: logger 'ResourceIndex:debug'

  constructor: (options) ->
    {@data} = options

  load: (hash, cb) ->
    file = "#{@data}/pieces/#{hash.substr(0, 2)}/#{hash}"
    @debug "load piece from #{file}..."

    fs.readFile file, (err, data) =>
      throw "error occurs while reading piece #{hash}" if err?

      cb data

