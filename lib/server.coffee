WebSocketServer = require('ws').Server
Serializable = require './Serializable'
url = require 'url'
logger = require 'debug'
debug = logger 'server:debug'
info = logger 'server:info'

# TODO: let it extends WebSocketServer?
exports = module.exports = class TrackerServer extends Serializable
  constructor: (@express, @server, @options) ->
    info 'server initializing...'

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

    # connected clients: clients[key][id] => connection
    # connection =
    #   token: ...
    #   ip: ...
    #   id: ...
    #   socket: ...
    @clients = {}

    # messages waiting for another peer: outstanding[key][id] => message[]
    # message =
    #   type: message.type
    #   src: id
    #   dst: message.dst
    #   payload: message.payload
    @outstanding = {}

    # concurrent users for a IP: ips[ip] => count
    @ips = {}

    info 'server initialized!'

  start: ->
    info 'server starting...'

    @setCleanupIntervals()
    @initializeWSS()

    info 'server started!'

  initializeWSS: ->
    # start server for WebSocket
    @wss = new WebSocketServer path: @mountpath, server: @server
    @wss.on 'connection', (socket) =>
      {key} = url.parse(socket.upgradeReq.url, true).query
      ip = socket.upgradeReq.socket.remoteAddress

      # check key is provided # FIXME: move to checkKey()
      unless key?
        payload = msg: 'key is required for connection'
        socket.send JSON.stringify type: 'ERROR', payload: payload
        socket.close()
        return

      debug "new connection from #{ip}, key: #{key}"

      # check key and limits
      # unless @clients[key]? and @clients[key][id]? # FIXME: check ID
      #                                                       later when JOIN
          # FIXME: handle these when join
          # else
          #   # register new client with token provided
          #   if @clients[key][id]?
          #     @clients[key][id] = token: token, ip: ip
          #     @ips[ip]++
          #     socket.send JSON.stringify type: 'OPEN'
      @checkKey key, ip, (err) ->
        if err?
          # close socket with error
          payload = msg: err
          # FIXME: change to close(code, message)
          socket.send JSON.stringify type: 'ERROR', payload: payload
          socket.close()
          return

      # configure incoming connection if no error
      # @configureWS socket, key, id, token # FIXME: id is no longer
      #                                              required until JOIN
      socket.on 'message', (data) =>
        content = @deserialize data

        # ignore malformed messages
        return unless content.type?

        # TODO emit information
        socket.emit content.type, content.payload

      # handle JOIN event
      socket.on 'JOIN', (payload) =>
        {peerId, token} = payload

        # generate ID if not provided
        peerId ?= @generateId()

        # TODO: handle join
        info "peer join!"
        content = @serialize type: 'JOINED', payload: peerId: @generateId()
        socket.send content

      # TODO: close connection in {timeout seconds} seconds if no JOIN request

  handleJoin: (socket, key, id, token) ->
    client = @clients[key][id]

    # restore connection
    if token is clients.token
      client.socket = socket
    else
      payload = msg: 'ID is taken'
      socket.send JSON.stringify type: 'ID-TAKEN', payload: payload
      socket.close()
      return

    # process outstanding messages for this client
    @processOutstanding key, id

    # cleanup on socket close
    socket.on 'close', ->
      info "client #{key}:#{id} has closed the connection"

      # remove peers after socket closed
      @removePeer key, id if client.socket is socket

    socket.on 'message', (data) ->
      debug "client #{key}:#{id} has sent the message #{JSON.stringify data}"

      try
        message = JSON.parse data

        if message.type in ['LEAVE', 'CANDIDATE', 'OFFER', 'ANSWER']
          content =
            type: message.type
            src: id
            dst: message.dst
            payload: message.payload
          @handleTransmission key, content
        else
          # TODO: handle other message type (mainly customized for the BCDN)
          debug "client #{key}:#{id} has sent a message with " +
            "invalid type: #{message.type}"
      catch e
        debug "error on handle message from #{key}:#{id}"

    # emit connect event
    @emit 'connect', client

  checkKey: (key, ip, cb) ->
    if key in @options.keys
      # initialize variables
      @clients[key] ?= {}
      @outstanding[key] ?= {}
      @ips[ip] ?= 0

      # check concurrent limit
      if Object.keys(@clients[key]).length >= @options.concurrent_limit
        cb 'server has reached its concurrent user limit'
        return
      if @ips[ip] >= @options.ip_limit
        cb "#{ip} has reached its concurrent user limit"
        return

      # key is valid
      cb null
    else
      cb 'invalid key provided'

  pruneOutstanding: ->
    for key, dsts of @outstanding
      for dst, offers of dsts
        seen = {}
        for message of offers
          unless seen[message.src]?
            content =
              type: 'EXPIRE'
              src: message.dst
              dst: message.src
            @handleTransmission key, content
            seen[message.src] = true
      @outstanding[key] = {}

  setCleanupIntervals: ->
    # clean up IPs every 10 minutes
    cleanupAction = =>
      for key, count of @ips
        delete @ips[key] if count is 0
    setInterval cleanupAction, 600000

    # clean up outstanding messages every 5 seconds
    cleanupAction = =>
      @pruneOutstanding()
    setInterval cleanupAction, 5000

    return

  processOutstanding: (key, id) ->
    offers = @outstanding[key][id]
    return unless offers?

    # do the pending transmission
    @handleTransmission key, offer for offer in offers

    # clear outstanding message for this client
    delete @outstanding[key][id]

  removePeer: (key, id) ->
    if @clients[key]? and @clients[key][id]?
      client = @clients[key][id]
      @ips[client.ip]--
      delete @clients[key][id]

      # emit disconnect event
      @emit 'disconnect', client

  handleTransmission: (key, message) ->
    {type, src, dst} = message
    data = JSON.stringify message

    destination = @clients[key][dst]

    if destination?
      try
        debug "send message from #{src} to #{dst}: #{JSON.stringify message}"
        if destination.socket?
          destination.socket.send data
        else
          throw 'Peer dead'
      catch e
        # This happens when a peer disconnects without closing connections and
        # the associated WebSocket has not closed.
        # Tell other side to stop trying.
        @removePeer key, dst
        content =
          type: 'LEAVE'
          src: dst
          dst: src
        @handleTransmission key, content
    else
      # Wait for this client to connect for important messages.
      if type isnt 'LEAVE' and type isnt 'EXPIRE' and dst?
        # save the message
        @outstanding[key][dst] ?= []
        @outstanding[key][dst].push message
      else if type is 'LEAVE' and not dst?
        @removePeer key, src
      else
        # Unavailable destination specified with message LEAVE or EXPIRE
        # Ignore
        return
  generateId: -> "P#{('0000000000' + Math.random().toString(10)).substr(-10)}"
