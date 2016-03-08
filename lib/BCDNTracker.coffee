PeerManager = require './PeerManager'
ContentsManager = require './ContentsManager'

logger = require 'debug'

exports = module.exports = class BCDNTracker
  debug: logger 'BCDNTracker:debug'
  info: logger 'BCDNTracker:info'

  constructor: (express, server, options) ->
    @info "tracker starting..."

    # configure mountpath for WebSocket servers
    if (mountpath = express.mountpath) instanceof Array
      throw new Error 'This app can only be mounted on a single path'
    mountpath += '/' unless mountpath.substr(-1) is '/'


    # parse options
    default_options =
      timeout: 5000
      keys: ['bcdn']
      ip_limit: 5000
      concurrent_limit: 5000
      data: './data'

    options = default_options extends options
    options.mountpath = mountpath
    options.keys = [options.keys] unless options.keys instanceof Array

    @debug "timeout: #{options.timeout}"
    @debug "keys: #{options.keys}"
    @debug "ip_limit: #{options.ip_limit}"
    @debug "concurrent_limit: #{options.concurrent_limit}"


    # initialize variables
    @contents = new ContentsManager options
    @contents.reloadContents (key) =>
      @peers.updateContentsFor key, @contents.get key
    @peers = new PeerManager server, "#{mountpath}peer", options
    @peers.on 'join', (peerConn) =>
      peerConn.updateContents @contents.get(peerConn.key).serialize()

    @info "tracker started"
