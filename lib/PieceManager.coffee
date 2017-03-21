fs = require 'fs'

logger = require 'debug'

# Manager for loading pieces.
class PieceManager
  # @property [String] path of the data directory.
  data: null

  # Create a piece manager instance.
  #
  # @param [Object<String, ?>] options options from {BCDNTracker} for initialize this piece manager.
  constructor: (options) ->
    {@data} = options

  # Asynchronously load a piece from file.
  #
  # @param [String] hash the piece hash.
  # @param [Function] cb the callback function which is invoked after the piece is loaded.
  load: (hash, cb) ->
    return unless typeof hash is 'string'

    file = "#{@data}/pieces/#{hash.substr(0, 2)}/#{hash}"
    @debug "-- load piece from #{file}..."

    fs.readFile file, (err, data) =>
      throw "error occurs while reading piece #{hash}" if err?

      cb data

  debug: logger 'ResourceIndex:debug'

exports = module.exports = PieceManager
