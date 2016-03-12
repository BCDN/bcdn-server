url = require 'url'
WebSocketServer = require('ws').Server

PeerConnection = require './PeerConnection'

logger = require 'debug'

exports = module.exports = class PeerManager extends WebSocketServer
  debug: logger 'PeerManager:debug'
  info: logger 'PeerManager:info'

  constructor: (server, mountpath, opts) ->
    {@keys, @timeout, @concurrent_limit, @ip_limit, tracker_id} = opts
    @info "peer manager starting (mountpath=#{mountpath})..."

    # initialize variables
    # connection for peers: peerConnections[key][id] => PeerConnection
    @peerConnections = {}
    # concurrent users for a IP: ips[ip] => count, clean up every 10 minutes
    @ips = {}
    setInterval =>
      delete @ips[ip] if count is 0 for ip, count of @ips
    , 600000

    # setup server for WebSocket
    super path: mountpath, server: server
    @on 'connection', (socket) =>
      # parse connect parameters
      {key, id, token} = url.parse(socket.upgradeReq.url, true).query
      connType = if token? then 'peer' else 'ping'


      # initialize peer connection
      generateId = ->
        "P#{('0000000000' + Math.random().toString(10)).substr(-10)}"
      peerId = "#{opts.tracker_id}-#{id || generateId()}"
      peerConn = new PeerConnection key, peerId, token, socket


      # check key and limits
      @checkKeyAndLimits peerConn.key, peerConn.ip, (errorMsg) ->
        peerConn.disconnectWithError errorMsg if errorMsg?


      # setup handlers for the peer connection
      peerConn.on 'CLOSE', =>
        @info "peer has left (key=#{peerConn.key}, id=#{peerConn.id})"
        @removePeerConnection peerConn
        @emit 'close', peerConn
      peerConn.on 'RESOURCE', (payload) =>
        {hash} = payload
        @emit 'queryResource', peerConn, hash
      peerConn.on 'SIGNAL', (payload) =>
        payload.from = peerConn.id
        @emit 'signal', payload

      # accept different types of connection
      switch connType
        when 'peer'
          @info "peer joining (key=#{peerConn.key}, id=#{peerConn.id})..."

          # register peer
          @registerPeerConnection peerConn, =>
            peerConn.accept()
            @emit 'join', peerConn

        when 'ping'
          @info "new ping connection (key=#{peerConn.key})"

          setInterval =>
            peerConn.disconnectWithError 'timeout for joining the network'
          , @timeout



  checkKeyAndLimits: (key, ip, cb) ->
    return cb 'key is required for connection' unless key?

    if key in @keys
      # initialize variables
      @ips[ip] ?= 0

      # check concurrent limit
      if Object.keys(@peerConnections).length >= @concurrent_limit
        cb 'tracker has reached its concurrent user limit'
        return
      if @ips[ip] >= @ip_limit
        cb "#{ip} has reached its concurrent user limit"
        return

      # key is valid
      cb null
    else
      cb 'invalid key provided'



  registerPeerConnection: (peer, cb) ->
    # register peer if haven't been registered yet
    if @peerConnections[peer.id]?
      if peer.token is @peerConnections[peer.id].token
        # connection need to be updated (close old connection)
        @peerConnections[peer.id].close()
        _action = "update"
      else
        return socket.disconnectWithError 'ID is taken'
    else
      @debug "number of connection for (ip=#{peer.ip}): #{@ips[peer.ip] + 1}"
      @ips[peer.ip]++
      _action = "register"

    @debug "#{_action} peer (key=#{peer.key}, id=#{peer.id})"
    @peerConnections[peer.id] = peer

    cb()



  removePeerConnection: (peer) ->
    if peer is @peerConnections[peer.id]
      @debug "remove peer (key=#{peer.key}, id=#{peer.id})"
      delete @peerConnections[peer.id]
      @debug "number of connection for (ip=#{peer.ip}): #{@ips[peer.ip] - 1}"
      @ips[peer.ip]--



  updateContentsFor: (key, contents) ->
    for id, peerConn of @peerConnections
      peerConn.updateContents contents if peerConn.key is key



  get: (id) -> @peerConnections[id]
