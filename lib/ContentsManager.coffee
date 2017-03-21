ContentsFile = require './ContentsFile'

# Manager for contents management for different namespaces (or keys).
class ContentsManager
  # @property [Array<String>] list of valid namespaces (or keys) for the network.
  keys: null
  # @property [String] path of the data directory.
  data: null
  # @property [Object<String, ContentsFile>] contents storage indexed by namespace (or key) (Object<key, contentsFile>).
  allContents: null

  # Create a contents manager instance.
  #
  # @param [Object<String, ?>] options options from {BCDNTracker} for initialize this contents manager.
  constructor: (options) ->
    {@keys, @data} = options
    @allContents = {}
    @allContents[key] = new ContentsFile() for key in @keys

  # Reload contents for all namespaces.
  #
  # @param [Function] cb the callback function which is invoked after all contents loaded.
  reloadContents: (cb) ->
    for key, contents of @allContents
      contents.deserialize "#{@data}/contents/#{key}", =>
        cb key

  # Get a contents by its namespace (or key).
  #
  # @param [String] key namespace (or key) of the contents.
  get: (key) -> @allContents[key]

exports = module.exports = ContentsManager
