ResourceIndex = require './ResourceIndex'

exports = module.exports = class ResourceManager
  constructor: (options) ->
    {@data} = options

  load: (hash, cb) ->
    resource = new ResourceIndex hash
    resource.deserialize "#{@data}/indexes/#{hash.substr(0, 2)}/#{hash}", =>
      cb resource
