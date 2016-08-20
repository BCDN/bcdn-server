url = require 'url'
WebSocketServer = require('ws').Server

PeerConnection = require './PeerConnection'

Util = require('bcdn').Util

logger = require 'debug'

# Manager for peer connections.
class PeerManager extends WebSocketServer
  debug: logger 'PeerManager:debug'
  info: logger 'PeerManager:info'

  # @property [Array<String>] valid connection key.
  keys: []
  # @property [Number] connection timeout (milliseconds).
  timeout: 0
  # @property [Number] concurrent limit for the tracker.
  concurrent_limit: 0
  # @property [Number] max concurrent connection per IP.
  ip_limit: 0
  # @property [String] tracker ID.
  tracker_id: ''
  # @property [Object<String, PeerConnection>] peer connections indexed by peer ID.
  peerConnections: {}
  # @property [Object<String, Number>] number of concurrent connections for each IP.
  ips: {}

  # Create a peer manager instance.
  #
  # @param [http.Server or https.Server] server the web server that this peer manager will be mounted on.
  # @param [String] mountpath the mount path for this peer manager.
  # @param [Object<String, ?>] options options from {BCDNTracker} for initialize this peer manager.
  constructor: (server, mountpath, options) ->
    {@keys, @timeout, @concurrent_limit, @ip_limit, @tracker_id} = options
    @info "peer manager starting (mountpath=#{mountpath})..."

    # setup clean up timer.
    setInterval =>
      delete @ips[ip] if count is 0 for ip, count of @ips
    , 600000

    # setup WebSocket server for peer manager.
    super path: mountpath, server: server
    @on 'connection', (socket) =>
      # parse connect parameters and identify connection type.
      properties = url.parse(socket.upgradeReq.url, true).query
      # FIXME: [improvement] connType can be reused from PeerConnection.
      connType = if properties.token? then 'peer' else 'ping'

      # generate peer ID staring with tracker ID.
      properties.id ?= "P#{Util.generateId()}"
      properties.id = "#{@tracker_id}-#{properties.id}"

      # wrap the socket in peer connection.
      peerConn = new PeerConnection properties, socket

      # check key and limits for this new connection, and disconnect on error.
      error = @checkKeyAndLimits peerConn.key, peerConn.ip
      return peerConn.disconnectWithError error if error?

      # setup packet handlers for this new connection.
      peerConn.on 'CLOSE', =>
        @info "peer has left (key=#{peerConn.key}, id=#{peerConn.id})"
        @removePeerConnection peerConn
        @emit 'close', peerConn
      peerConn.on 'DOWNLOAD', (payload) =>
        {hash} = payload
        @emit 'download', peerConn, hash
      peerConn.on 'SIGNAL', (payload) =>
        payload.from = peerConn.id
        @emit 'signal', payload
      peerConn.on 'FETCH', (piece) =>
        @emit 'fetch', peerConn, piece

      # accept different types of connections.
      switch connType
        when 'peer'
          @info "peer joining (key=#{peerConn.key}, id=#{peerConn.id})..."

          # register the peer connection and disconnect on error.
          error = @registerPeerConnection peerConn
          return peerConn.disconnectWithError error if error?

          # accept the connection.
          peerConn.accept()
          @emit 'join', peerConn

        when 'ping'
          @info "new ping connection (key=#{peerConn.key})"

          # Set a timer always close the ping connection in certain period of time.
          setTimeout =>
            peerConn.disconnectWithError 'timeout for joining the network'
          , @timeout

  # Check the connection key is valid and check the connection against the limit.
  #
  # @param [String] key the connection key provided by peer node.
  # @param [String] ip the peer node IP.
  # @return [String] error message only when error occurred.
  checkKeyAndLimits: (key, ip) ->
    # verify connection key.
    return 'key is required for connection' unless key?
    return 'invalid key provided' if key not in @keys

    # initialize number of connections for this IP if not yet been initialized.
    @ips[ip] ?= 0

    # check concurrent limit.
    if Object.keys(@peerConnections).length >= @concurrent_limit
      return 'tracker has reached its concurrent connection limit'
    if @ips[ip] >= @ip_limit
      return "#{ip} has reached its concurrent connection limit"

    # and return empty error message to indicate key is valid.
    return

  # Check if peer ID has been registered, and register peer connection if possible.
  #
  # @param [PeerConnection] peer peer connection to be registered.
  # @return [String] error message only when error occurred.
  registerPeerConnection: (peer) ->
    # trying to resume connection if peer ID has already been registered.
    if @peerConnections[peer.id]?
      # verify peer token matches the one recorded on last connection, and update the connection.
      if peer.token is @peerConnections[peer.id].token
        _action = "update"
        # close the old connection first.
        @peerConnections[peer.id].close()
      # if tokens are not matched, return error message.
      else
        return 'ID is taken'
    # register the peer connected if its ID haven't been registered yet.
    else
      _action = "register"
      # increment the number of concurrent connection for this IP.
      @ips[peer.ip]++
      @debug "number of connection for (ip=#{peer.ip}): #{@ips[peer.ip]}"

    # register or update the peer connection table.
    @debug "#{_action} peer (key=#{peer.key}, id=#{peer.id})"
    @peerConnections[peer.id] = peer

    # and return empty error message to indicate the successful registration.
    return

  # Remove a peer connection.
  #
  # @param [PeerConnection] peer per connection to be removed.
  removePeerConnection: (peer) ->
    # first make sure the peer has already been registered.
    if peer is @peerConnections[peer.id]
      # then remove the connection and decrement the number of concurrent connection for this IP.
      @debug "remove peer (key=#{peer.key}, id=#{peer.id})"
      delete @peerConnections[peer.id]
      @debug "number of connection for (ip=#{peer.ip}): #{@ips[peer.ip] - 1}"
      @ips[peer.ip]--

  # Push new contents for peer connections with certain connection key.
  #
  # @param [String] key the connection key.
  # @param [ContentsFile] contents new contents.
  updateContentsFor: (key, contents) ->
    for id, peerConn of @peerConnections
      peerConn.updateContents contents if peerConn.key is key

  # Get peer connection by ID.
  #
  # @param [String] peer ID.
  # @return [PeerConnection] peer connection.
  get: (id) -> @peerConnections[id]

exports = module.exports = PeerManager
