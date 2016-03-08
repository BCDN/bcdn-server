ContentsFile = require './ContentsFile'

exports = module.exports = class ContentsManager
  constructor: (@options) ->
    @allContents = {}
    @allContents[key] = new ContentsFile() for key in @options.keys

  reloadContents: (cb) ->
    for key, contents of @allContents
      contents.deserialize "#{@options.data}/#{key}", =>
        cb key

  get: (key) -> @allContents[key]

