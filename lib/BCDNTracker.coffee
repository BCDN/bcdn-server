url = require 'url'
WebSocketServer = require('ws').Server

Contents = require('bcdn').Contents
Serializable = require('bcdn').Serializable
PeerConnection = require './PeerConnection'
ContentsFile = require './ContentsFile'

logger = require 'debug'

# TODO: let it extends WebSocketServer?
exports = module.exports = class BCDNTracker
  debug: logger 'BCDNTracker:debug'
  info: logger 'BCDNTracker:info'

  constructor: (@express, @server, @options) ->
    @info "tracker starting..."


    # configure express
    if @mountpath = @express.mountpath instanceof Array
      throw new Error 'This app can only be mounted on a single path'


    # parse options
    default_options =
      timeout: 5000
      keys: ['bcdn']
      ip_limit: 5000
      concurrent_limit: 5000
      data: './data'

    @options = default_options extends @options

    @options.keys = [@options.keys] unless @options.keys instanceof Array

    @debug "timeout: #{@options.timeout}"
    @debug "keys: #{@options.keys}"
    @debug "ip_limit: #{@options.ip_limit}"
    @debug "concurrent_limit: #{@options.concurrent_limit}"


    # initialize variables
    # connection for peers: peers[key][id] => PeerConnection
    @peers = {}
    @peers[key] ?= {} for key in @options.keys

    # concurrent users for a IP: ips[ip] => count
    @ips = {}

    # contents for a namespace: contents[key] => contents
    @contents = {}
    @contents[key] = new ContentsFile() for key in @options.keys

    @info "tracker initialized"


    # start up the tracker
    @updateAllContents()
    @setCleanupIntervals()
    @startWebSocketServer()

    @info "tracker started"



  startWebSocketServer: ->
    # setup server for WebSocket
    @wss = new WebSocketServer path: @mountpath, server: @server
    @wss.on 'connection', (socket) =>
      # parse connect parameters
      {key, id, token} = url.parse(socket.upgradeReq.url, true).query
      connType = if token? then 'peer' else 'ping'


      # initialize peer connection
      generateId = ->
        "P#{('0000000000' + Math.random().toString(10)).substr(-10)}"
      peerConn = new PeerConnection key, id || generateId(), token, socket


      # check key and limits
      @checkKeyAndLimits peerConn.key, peerConn.ip, (errorMsg) ->
        peerConn.disconnectWithError errorMsg if errorMsg?


      # setup handlers for the peer connection
      peerConn.on 'CLOSE', =>
        @info "peer has left (key=#{peerConn.key}, id=#{peerConn.id})"
        @removePeer peerConn
      # TODO: setup more handlers
      # peerConn.on 'RESOURCE'


      # accept different types of connection
      switch connType
        when 'peer'
          @info "peer joining (key=#{peerConn.key}, id=#{peerConn.id}..."

          # register peer
          @registerPeer peerConn, =>
            peerConn.accept()
            peerConn.updateContents @contents[peerConn.key].serialize()

        when 'ping'
          @info "new ping connection (key=#{peerConn.key})"

          setInterval =>
            peerConn.disconnectWithError 'timeout for joining the network'
          , @options.timeout



  registerPeer: (peer, cb) ->
    # register peer if haven't been registered yet
    if @peers[peer.key][peer.id]?
      if peer.token is @peers[peer.key][peer.id].token
        # connection need to be updated (close old connection)
        @peers[peer.key][peer.id].close()
        _action = "update"
      else
        return socket.disconnectWithError 'ID is taken'
    else
      @debug "number of connection for (ip=#{peer.ip}): #{@ips[peer.ip] + 1}"
      @ips[peer.ip]++
      _action = "register"

    @debug "#{_action} peer (key=#{peer.key}, id=#{peer.id})"
    @peers[peer.key][peer.id] = peer

    cb()



  checkKeyAndLimits: (key, ip, cb) ->
    return cb 'key is required for connection' unless key?

    if key in @options.keys
      # initialize variables
      @ips[ip] ?= 0

      # check concurrent limit
      if Object.keys(@peers[key]).length >= @options.concurrent_limit
        cb 'tracker has reached its concurrent user limit'
        return
      if @ips[ip] >= @options.ip_limit
        cb "#{ip} has reached its concurrent user limit"
        return

      # key is valid
      cb null
    else
      cb 'invalid key provided'



  setCleanupIntervals: ->
    # clean up IPs every 10 minutes
    cleanupAction = =>
      for key, count of @ips
        delete @ips[key] if count is 0
    setInterval cleanupAction, 600000



  removePeer: (peer) ->
    if peer is @peers[peer.key][peer.id]
      @debug "remove peer (key=#{peer.key}, id=#{peer.id})"
      delete @peers[peer.key][peer.id]
      @debug "number of connection for (ip=#{peer.ip}): #{@ips[peer.ip] - 1}"
      @ips[peer.ip]--



  updateAllContents: ->
    for key, content of @contents
      content.deserialize "./data/#{key}", =>
        for id, peerConn of @peers[key]
          peerConn.updateContents content.serialize()
