logger = require 'debug'

exports = module.exports = class ResourceTracking
  debug: logger 'ResourceTracking:debug'
  # tracking[hash] => downloading: peerId: peerConnection,
  #                       sharing: peerId: peerConnection
  tracking: {}

  download: (peer, hash) ->
    # use cached tracking information if applicable
    @tracking[hash] = downloading: {}, sharing: {} unless @tracking[hash]?
    @tracking[hash].downloading[peer.id] = peer
    @debug "peer=#{peer} start downloading resource=#{hash}"

  share: (peer, hash) ->
    delete @tracking[hash].downloading[peer.id]
    @tracking[hash].sharing[peer.id] = peer
    @debug "peer=#{peer} start sharing resource=#{hash}"

  leave: (peer, hash) ->
    delete @tracking[hash].downloading[peer.id]
    delete @tracking[hash].sharing[peer.id]
    if Object.keys(@tracking[hash].downloading).length is 0 and
       Object.keys(@tracking[hash].sharing).length is 0
      delete @tracking[hash]
    @debug "peer=#{peer} has left for resource=#{hash}"
      # FIXME: delete resource cache from resource manager
