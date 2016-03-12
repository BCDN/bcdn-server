logger = require 'debug'

exports = module.exports = class ResourceTracking
  debug: logger 'ResourceTracking:debug'
  # tracking[hash] => downloading: peerId: peerConnection,
  #                       sharing: peerId: peerConnection
  tracking: {}

  download: (peer, hash) ->
    # use cached tracking information if applicable
    unless @tracking[hash]?
      @tracking[hash] =
        downloading: new Set(),
        sharing:     new Set()

    @tracking[hash].downloading.add peer
    @debug "peer=#{peer} start downloading resource=#{hash}"

  share: (peer, hash) ->
    if (@tracking[hash].downloading.delete peer) or
       (@tracking[hash].sharing.add peer)
      @debug "peer=#{peer} start sharing resource=#{hash}"

  leave: (peer, hash) ->
    if (@tracking[hash].downloading.delete peer) or
       (@tracking[hash].sharing.delete peer)
      @debug "peer=#{peer} has left for resource=#{hash}"

    if @tracking[hash].downloading.size is 0 and
       @tracking[hash].sharing.size is 0
      delete @tracking[hash]
    # FIXME: delete resource cache from resource manager if nobody need it

  close: (peer) ->
    for hash in Object.keys @tracking
      @leave peer, hash

  get: (hash) ->
    @tracking[hash] and
      hash: hash
      downloading: Array.from @tracking[hash].downloading
      sharing: Array.from @tracking[hash].sharing
