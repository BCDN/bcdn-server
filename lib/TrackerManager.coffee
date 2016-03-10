url = require 'url'
WebSocketServer = require('ws').Server
WebSocket = require 'ws'

ResourceState = require('bcdn').ResourceState
TrackerConnection = require './TrackerConnection'

logger = require 'debug'

exports = module.exports = class TrackerManager extends WebSocketServer
  debug: logger 'TrackerManager:debug'
  info: logger 'TrackerManager:info'

  trackers: {}

  constructor: (server, mountpath, opts) ->
    {trackers, @secret, @timeout, @tracker_id} = opts
    @trackerURLs = trackers

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

      connection.accept @tracker_id

      connection.socket.on 'ANNOUNCE', (payload) =>
        @emit 'announce', payload

    # initialize variables
    # connection for trackers: trackerConnections[id] => TrackerConnection
    @trackerConnections = {}

    @on 'listening', =>
      for trackerURL in @trackerURLs
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

            @trackers[id] = connection



  announce: (info) -> @boardcast type: 'ANNOUNCE', payload: info
  announceDownload: (peer, hash) ->
    @announce peer: peer, hash: hash, state: ResourceState.DOWNLOADING
  announceShare: (peer, hash) ->
    @announce peer: peer, hash: hash, state: ResourceState.SHARING
  announceLeave: (peer, hash) ->
    @announce peer: peer, hash: hash, state: ResourceState.DONE



  boardcast: (msg) ->
    tracker.send msg for id, tracker of @trackers
