fs = require 'fs'

Resource = require('bcdn').Resource

logger = require 'debug'

# Resource wrapper for reading Resource from file.
#
# @extend Resource
class ResourceIndex extends Resource
  # Override deserialize method to load Resource from file.
  #
  # @param [String] file the path of the resource file.
  # @param [Function] cb the callback function which is invoked after resource loaded.
  deserialize: (file, cb) ->
    @debug "-- load resource index from #{file}..."

    fs.readFile file, 'utf8', (err, data) =>
      throw "error occurs while reading resource index" if err?

      # parse indexes
      @pieces = (piece for piece in data.split '\n' when piece isnt '')
      cb()

  debug: logger 'ResourceIndex:debug'

exports = module.exports = ResourceIndex
