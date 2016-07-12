url = require 'url'
WebSocketServer = require('ws').Server
WebSocket = require 'ws'

TrackerConnection = require './TrackerConnection'

logger = require 'debug'

exports = module.exports = class TrackerManager extends WebSocketServer
  debug: logger 'TrackerManager:debug'
  info: logger 'TrackerManager:info'

  constructor: (server, mountpath, opts) ->
    {@trackers, @secret, @timeout, @tracker_id} = opts

    # initialize variables
    # connection for trackers: trackerConnections[id] => TrackerConnection
    @trackerConnections = {}

    @info "tracker manager starting (mountpath=#{mountpath}, " +
                                     "id=#{@tracker_id})..."

    # setup server for WebSocket
    super path: mountpath, server: server
    @on 'connection', (socket) =>
      # parse connect parameters
      {id, secret} = url.parse(socket.upgradeReq.url, true).query
      socket.close() unless secret is @secret

      connection = new TrackerConnection socket, id
      unless id is @tracker_id
        @trackerConnections[id] = connection
        @info "tracker connected (id=#{id})..."

      connection.accept id: @tracker_id

      connection.socket.on 'ANNOUNCE', (payload) =>
        @emit 'announce', payload

      connection.socket.on 'SIGNAL', (payload) =>
        @emit 'signal', payload

    @on 'listening', =>
      for trackerURL in @trackers
        do (trackerURL) =>
          socket = new WebSocket "#{trackerURL}?id=#{@tracker_id}" +
                                 "&secret=#{@secret}"
          connection = new TrackerConnection socket

          wait = setTimeout =>
            @debug "timeout to accept the connection"
            socket.close()
          , @timeout

          socket.on 'ACCEPT', (payload) =>
            {id} = payload
            clearTimeout wait
            connection.id = id
            @trackerConnections[id] = connection
            @info "tracker connected (id=#{connection.id})..."



  announce: (info) -> @boardcast type: 'ANNOUNCE', payload: info
  announceTrack: (peer, hash) ->
    @announce peer: peer, action: 'track', hash: hash
  announceLeave: (peer, hash) ->
    @announce peer: peer, action: 'leave', hash: hash
  announceClose: (peer) ->
    @announce peer: peer, action: 'close'



  boardcast: (msg) ->
    tracker.send msg for id, tracker of @trackerConnections



  passSignal: (detail) ->
    {to} = detail
    targetTracker = to.split('-')[0]
    target.signal detail if (target = @trackerConnections[targetTracker])?
