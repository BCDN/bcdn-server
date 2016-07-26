PeerManager = require './PeerManager'
TrackerManager = require './TrackerManager'
ContentsManager = require './ContentsManager'
ResourceManager = require './ResourceManager'
PieceManager = require './PieceManager'
ResourceTracking = require './ResourceTracking'

Util = require('bcdn').Util

logger = require 'debug'

# Entry point of tracker node.
class BCDNTracker
  debug: logger 'BCDNTracker:debug'
  info: logger 'BCDNTracker:info'

  # Create a BCDN tracker instance.
  #
  # @param [WebServer] server the web server that mounts the tracker.
  # @param [String] mountpath the path that the tracker will be mounted on.
  # @param [Object] options options for the tracker node.
  # @option options [Number] timeout timeout (in milliseconds) for connections.
  # @option options [Number] ip_limit limit for number of connections per IP.
  constructor: (server, mountpath, options) ->
    @info "tracker starting..."

    # configure mountpath for WebSocket servers
    if mountpath instanceof Array
      throw new Error "This app can only be mounted on a single path"
    mountpath += '/' unless mountpath.substr(-1) is '/'

    # parse options
    default_options =
      timeout: 5000
      keys: ['bcdn']
      ip_limit: 5000
      concurrent_limit: 5000
      data: './data'

    # handle options
    options = default_options extends options
    # add mount path
    options.mountpath = mountpath
    # make keys an array
    options.keys = [options.keys] unless options.keys instanceof Array
    # make trackers an array
    unless options.trackers instanceof Array
      options.trackers = [options.trackers]
    # add local tracker to the tracker list
    options.trackers.unshift "ws://#{options.host}:#{options.port}" +
                             "#{mountpath}tracker"
    options.tracker_id ?= "T#{Util.generateId()}"

    @debug "timeout: #{options.timeout}"
    @debug "keys: [#{options.keys}]"
    @debug "ip_limit: #{options.ip_limit}"
    @debug "concurrent_limit: #{options.concurrent_limit}"
    @debug "data: #{options.data}"
    @debug "trackers: [#{options.trackers}]"

    # initialize variables
    @peers = new PeerManager server, "#{mountpath}peer", options
    @trackers = new TrackerManager server, "#{mountpath}tracker", options
    @contents = new ContentsManager options
    @resources = new ResourceManager options
    @pieces = new PieceManager options
    @tracking = new ResourceTracking()

    # load content on tracker start
    @contents.reloadContents (key) =>
      @peers.updateContentsFor key, @contents.get key

    # update content on peer join
    @peers.on 'join', (peerConn) =>
      peerConn.updateContents @contents.get(peerConn.key).serialize()
    @peers.on 'close', (peerConn) =>
      @trackers.announceClose peerConn.id
    @peers.on 'download', (peerConn, hash) =>
      @resources.load hash, (resource) =>
        peerConn.sendResourceInfo
          hash: hash
          resource: resource.serialize()
          candidates: @tracking.get hash
        @trackers.announceTrack peerConn.id, hash
    @peers.on 'signal', (detail) =>
      @trackers.passSignal detail
    @peers.on 'fetch', (peerConn, piece) =>
      @pieces.load piece, (buffer) =>
        peerConn.socket.send buffer, binary: true, mask: true

    # handle peer announcement
    @trackers.on 'announce', (payload) =>
      {peer, action, hash} = payload
      switch action
        when 'track'
          @tracking.track peer, hash
        when 'leave'
          @tracking.leave peer, hash
        when 'close'
          @tracking.close peer
    @trackers.on 'signal', (payload) =>
      {to} = payload
      if (peer = @peers.get to)?
        peer.signal payload

    @info "tracker started"

exports = module.exports = BCDNTracker
