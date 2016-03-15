ResourceIndex = require './ResourceIndex'

exports = module.exports = class ResourceManager
  constructor: (options) ->
    {@data} = options

    # resources[hash] => resource
    @resources = {}

  load: (hash, cb) ->
    return cb @resources[hash] if @resources[hash]?

    resource = new ResourceIndex hash
    resource.deserialize "#{@data}/indexes/#{hash.substr(0, 2)}/#{hash}", =>
      @resources[hash] = resource
      cb resource
