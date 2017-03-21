ResourceIndex = require './ResourceIndex'

# Manager for lazy loading resources.
class ResourceManager
  # @property [String] .
  data: null
  # @property [Object<String, ResourceIndex>] the resource storage indexed by resource hash (Object<resourceHash, resourceIndex>).
  resources: null

  # Create a resource manager instance.
  #
  # @param [Object<String, ?>] options options from {BCDNTracker} for initialize this resource manager.
  constructor: (options) ->
    {@data} = options

    # resources[hash] => resource
    @resources = {}

  # Asynchronously lazy load a resource from file.
  #
  # @param [String] hash the resource hash.
  # @param [Function] cb the callback function which is invoked after the resource is loaded.
  load: (hash, cb) ->
    return cb @resources[hash] if @resources[hash]?

    resource = new ResourceIndex hash
    resource.deserialize "#{@data}/indexes/#{hash.substr(0, 2)}/#{hash}", =>
      @resources[hash] = resource
      cb resource

exports = module.exports = ResourceManager
