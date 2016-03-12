ResourceState = require('bcdn').ResourceState
PeerManager = require './PeerManager'
TrackerManager = require './TrackerManager'
ContentsManager = require './ContentsManager'
ResourceManager = require './ResourceManager'
ResourceTracking = require './ResourceTracking'

logger = require 'debug'

exports = module.exports = class BCDNTracker
  debug: logger 'BCDNTracker:debug'
  info: logger 'BCDNTracker:info'

  constructor: (express, server, options) ->
    @info "tracker starting..."

    # configure mountpath for WebSocket servers
    if (mountpath = express.mountpath) instanceof Array
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
    generateId = ->
      "T#{('0000000000' + Math.random().toString(10)).substr(-10)}"
    options.tracker_id ?= generateId()

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
    @tracking = new ResourceTracking()

    # load content on tracker start
    @contents.reloadContents (key) =>
      @peers.updateContentsFor key, @contents.get key

    # update content on peer join
    @peers.on 'join', (peerConn) =>
      peerConn.updateContents @contents.get(peerConn.key).serialize()
    @peers.on 'close', (peerConn) =>
      @trackers.announceClose peerConn.id
    @peers.on 'queryResource', (peerConn, hash) =>
      @resources.load hash, (resource) =>
        peerConn.sendResourceIndex resource.serialize()
        @trackers.announceDownload peerConn.id, hash
        peerConn.sendCandidate candidates if (candidates = @tracking.get hash)?

    # handle peer announcement
    @trackers.on 'announce', (payload) =>
      {peer, hash, state} = payload
      switch state
        when ResourceState.DOWNLOADING
          @tracking.download peer, hash
          peers = Array.from @tracking.get(hash).downloading
        when ResourceState.SHARING
          @tracking.share peer, hash
        when ResourceState.DONE
          @tracking.leave peer, hash
        else
          @tracking.close peer

    @info "tracker started"
