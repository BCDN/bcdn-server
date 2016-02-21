WebSocketServer = require('ws').Server
url = require 'url'

exports = module.exports = class
  constructor: (@express, @server, @options) ->
    if @mountpath = @express.mountpath instanceof Array
      throw new Error 'This app can only be mounted on a single path'

    default_options =
      timeout: 5000
      keys: ['bcdn']
      ip_limit: 5000
      concurrent_limit: 5000
    default_options extends @options

    # connected clients: clients[key][id] => connection
    # connection =
    #   token: ...
    #   id: ...
    #   socket: ...
    @clients = {}

    # messages waiting for another peer: outstanding[key][id] => message
    # message =
    #   type: message.type
    #   src: id
    #   dst: message.dst
    #   payload: message.payload
    @outstanding = {}

    # concurrent users for a IP: ips[ip] => count
    @ips = {}

  start: ->
    @setCleanupIntervals()
    @initializeWSS()

  stop: ->
    # TODO: implement stop method
    return

  initializeWSS: ->
    # start server for WebSocket
    @wss = new WebSocketServer path: @mountpath, server: @server
    @wss.on 'connection', (socket) ->
      {id, token, key} = url.parse(socket.upgradeReq.url, true).query
      ip = socket.upgradeReq.socket.remoteAddress

      # generate ID if not provided
      id ?= @generateId()

      # check parameters
      unless token? and key?
        payload = msg: 'No token, or key supplied to websocket server'
        socket.send JSON.stringify type: 'ERROR', payload: payload
        socket.close()
        return

      # check key and limits
      unless @clients[key]? and @clients[key][id]?
        checkKey key, ip, (err) ->
          if err?
            # close socket with error
            payload = msg: err
            socket.send JSON.stringify type: 'ERROR', payload: payload
            socket.close()
            return
          else
            # register new client with token provided
            if @clients[key][id]?
              @clients[key][id] = token: token, ip: ip
              @ips[ip]++
              socket.send JSON.stringify type: 'OPEN'

      # configure incoming connection if no error
      @configureWS socket, key, id, token

  configureWS: (socket, key, id, token) ->
    client = @clients[key][id]

    # restore connection
    if token is clients.token
      client.socket = socket
    else
      payload = msg: 'ID is taken'
      socket.send JSON.stringify type: 'ID-TAKEN', payload: payload
      socket.close()
      return

    # TODO?
    @processOutstanding key, id

    # cleanup on socket close
    socket.on 'close', ->
      # TODO: logging?
      # remove peers after socket closed
      @removePeer key, id if client.socket is socket

    socket.on 'message', (data) ->
      try
        message = JSON.parse data

        if message.type in ['LEAVE', 'CANDIDATE', 'OFFER', 'ANSWER']
          content =
            type: message.type
            src: id
            dst: message.dst
            payload: message.payload
          @handleTransmission key, content
        # else
          # TODO: handle unrecognized type?
      catch e
        # ...
        # TODO: log error?
        # TODO: throw or ignore?
        throw e

    # emit connect event TODO: add other info? like IP maybe?
    @emit 'connect', id

  checkKey: (key, ip, cb) ->
    if key in @options.keys
      # initialize variables
      @clients[key] ?= {}
      @outstanding[key] ?= {}
      @ips[ip] ?= 0

      # check concurrent limit
      if Object.keys(@clients[key]).length >= @options.concurrent_limit
        cb 'Server has reached its concurrent user limit'
        return
      if @ips[ip] >= @options.ip_limit
        cb "#{ip} has reached its concurrent user limit"
        return

      # key is valid
      cb null
    else
      cb 'Invalid key provided'

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
    cleanupAction = ->
      for key, count of @ips
        delete @ips[key] if count is 0
    setInterval cleanupAction, 600000

    # clean up outstanding messages every 5 seconds
    cleanupAction = ->
      @pruneOutstanding()
    setInterval cleanupAction, 5000

  processOutstanding: (key, id) ->
    offers = @outstanding[key][id]
    return unless offers?

    # TODO: ??
    @handleTransmission key, offer for offer in offers

    delete @outstanding[key][id]

  removePeer: (key, id) ->
    if @clients[key]? and @clients[key][id]?
      ip = @clients[key][id].ip
      @ips[ip]--
      delete @clients[key][id]
      # emit disconnect event TODO: add other info? like IP maybe?
      @emit 'disconnect', id

  handleTransmission: (key, message) ->
    {type, src, dst} = message
    data = JSON.stringify message

    destination = @clients[key][dst]

    if destination?
      try
        # TODO: logging?
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
