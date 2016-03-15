logger = require 'debug'

exports = module.exports = class ResourceTracking
  debug: logger 'ResourceTracking:debug'

  constructor: ->
    # tracking[hash] => peerId: peerConnection
    @tracking = {}

  track: (peer, hash) ->
    # use cached tracking information if applicable
    @tracking[hash] = new Set() unless @tracking[hash]?
    @tracking[hash].add peer
    @debug "track peer=#{peer} for downloading resource=#{hash}"

  leave: (peer, hash) ->
    if @tracking[hash].delete peer
      @debug "peer=#{peer} has left for resource=#{hash}"

    delete @tracking[hash] if @tracking[hash].size is 0
    # FIXME: delete resource cache from resource manager if nobody need it

  close: (peer) ->
    @leave peer, hash for hash in Object.keys @tracking

  get: (hash) ->
    @tracking[hash]? and (Array.from @tracking[hash]) or []
