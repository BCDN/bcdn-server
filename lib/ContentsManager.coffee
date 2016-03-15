ContentsFile = require './ContentsFile'

exports = module.exports = class ContentsManager
  constructor: (options) ->
    {@keys, @data} = options
    @allContents = {}
    @allContents[key] = new ContentsFile() for key in @keys

  reloadContents: (cb) ->
    for key, contents of @allContents
      contents.deserialize "#{@data}/contents/#{key}", =>
        cb key

  get: (key) -> @allContents[key]

