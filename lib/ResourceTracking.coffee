logger = require 'debug'

# The resource tracking module.
class ResourceTracking
  # @property [Object<String, Set<String>>] tracked peer IDs indexed by resource hash (Object<resourceHash, Set<peerId>>).
  tracking: null

  # Create a tracker instance for resource tracking.
  constructor: ->
    # tracking[hash] => Set[peerId]
    @tracking = {}

  # Track a peer downloading a specific resource.
  #
  # @param [String] peer ID of the peer.
  # @param [String] hash hash of the resource.
  track: (peer, hash) ->
    # use cached tracking information if applicable.
    @tracking[hash] = new Set() unless @tracking[hash]?
    @tracking[hash].add peer
    @info "-- track peer=#{peer} for downloading resource=#{hash}"

  # Untrack a peer due to leaving reason.
  #
  # @param [String] peer ID of the peer.
  # @param [String] hash hash of the resource.
  leave: (peer, hash) ->
    if @tracking[hash].delete peer
      @info "-- peer=#{peer} has left for resource=#{hash}"

    delete @tracking[hash] if @tracking[hash].size is 0
    # FIXME: delete resource cache from resource manager if nobody need it

  # Untrack all peer resource states due to connnection closing.
  #
  # @param [String] peer ID of the peer.
  close: (peer) ->
    @leave peer, hash for hash in Object.keys @tracking

  # Get a list of peer IDs related to the resource.
  #
  # @param [String] hash hash of the resource.
  get: (hash) ->
    @tracking[hash]? and (Array.from @tracking[hash]) or []

  info: logger 'ResourceTracking:info'

exports = module.exports = ResourceTracking
