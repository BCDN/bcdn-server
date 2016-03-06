WebSocketServer = require('ws').Server
Serializable = require './Serializable'
url = require 'url'
logger = require 'debug'
debug = logger 'tracker:debug'
info = logger 'tracker:info'

# TODO: let it extends WebSocketServer?
exports = module.exports = class TrackerServer extends Serializable
  constructor: (@express, @server, @options) ->
    info 'tracker initializing...'

    if @mountpath = @express.mountpath instanceof Array
      throw new Error 'This app can only be mounted on a single path'

    default_options =
      timeout: 5000
      keys: ['bcdn']
      ip_limit: 5000
      concurrent_limit: 5000
    @options = default_options extends @options

    @options.keys = [@options.keys] unless @options.keys instanceof Array

    debug "timeout: #{@options.timeout}"
    debug "keys: #{@options.keys}"
    debug "ip_limit: #{@options.ip_limit}"
    debug "concurrent_limit: #{@options.concurrent_limit}"

    # connected peers: peers[key][id] => connection
    # connection =
    #   token: ...
    #   ip: ...
    #   id: ...
    #   socket: ...
    @peers = {}

    # concurrent users for a IP: ips[ip] => count
    @ips = {}

    info 'tracker initialized'

  start: ->
    info 'tracker starting...'

    @setCleanupIntervals()
    @startWebSocketServer()

    info 'tracker started'

  startWebSocketServer: ->
    @wss = new WebSocketServer path: @mountpath, server: @server
    @wss.on 'connection', (socket) =>
      {key} = url.parse(socket.upgradeReq.url, true).query
      socket.ip = socket.upgradeReq.socket.remoteAddress

      # check key is provided # FIXME: move to checkKey()
      @disconnectWithError socket, 'key is required for connection' unless key?

      info "new connection (ip=#{socket.ip}, key=#{key})"

      # check key and limits
      @checkKey key, socket.ip, (errorMsg) ->
        # close socket with error
        @disconnectWithError socket, errorMsg if errorMsg?

      socket.on 'message', (data) =>
        try
          content = @deserialize data
        catch e
          debug "error to deserialize: #{e}, (data=#{data})"
          return

        # sanitize malformed messages
        return unless content.type in ['JOIN']

        debug "peer has sent a message (data=#{data})"

        # emit information
        socket.emit content.type, content.payload

      # close connection in {timeout} seconds if no JOIN request
      joiningTimer = setInterval =>
        @disconnectWithError socket, 'timeout for joining the network'
      , @options.timeout

      # close for tracker selection ping
      socket.on 'ping', (data) =>
        debug "got ping (ip=#{socket.ip}, data=#{data})"

        if data is 'HELLO'
          socket.close()

      # handle JOIN event
      socket.on 'JOIN', (payload) =>
        {id, token} = payload

        # clear the joining timer
        clearInterval joiningTimer

        # generate ID if not provided
        id ?= @generateId()

        # handle join
        @handleJoin socket, key, id, token

  disconnectWithError: (socket, msg) ->
    # 1002 - CLOSE_PROTOCOL_ERROR for WebSocket
    content = @serialize type: 'ERROR', payload: msg: msg
    socket.close 1002, content

  handleJoin: (socket, key, id, token) ->
    info "peer joining (ip=#{socket.ip}, " +
         "key=#{key}, id=#{id}, token=#{token})..."

    # register peer if haven't been registered yet
    unless @peers[key][id]?
      debug "register peer (ip=#{socket.ip}, key=#{key}, id=#{id})"
      @peers[key][id] = token: token, ip: socket.ip
      @ips[socket.ip]++
      debug "number of connection for (ip=#{socket.ip}): #{@ips[socket.ip]}"

    # get record for the peer
    peer = @peers[key][id]

    # store connection
    if token is peer.token
      peer.socket = socket
    else
      @disconnectWithError socket, 'ID is taken'

    peer.socket.on 'close', =>
      info "peer has left (key=#{key}, id=#{id})"

      # remove peers after socket closed
      @removePeer key, id if peer.socket is socket

    # notify peer has joined the network
    content = @serialize type: 'JOINED', payload: id: id
    peer.socket.send content

    # TODO: push update to peer

  checkKey: (key, ip, cb) ->
    if key in @options.keys
      # initialize variables
      @peers[key] ?= {}
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

  removePeer: (key, id) ->
    peer = @peers[key][id]

    if peer?
      debug "remove peer (ip=#{peer.ip}, key=#{key}, id=#{id})"
      @ips[peer.ip]--
      debug "number of connection for (ip=#{peer.ip}): #{@ips[peer.ip]}"
      delete @peers[key][id]

  generateId: -> "P#{('0000000000' + Math.random().toString(10)).substr(-10)}"
