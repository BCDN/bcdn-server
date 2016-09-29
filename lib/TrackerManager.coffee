url = require 'url'
WebSocketServer = require('ws').Server
WebSocket = require 'ws'

TrackerConnection = require './TrackerConnection'

logger = require 'debug'

# Manager for tracker connections.
class TrackerManager extends WebSocketServer
  # @property [String] shared secret used for establish tracker communication.
  secret: ''
  # @property [Number] connection timeout (milliseconds).
  timeout: 0
  # @property [String] tracker ID.
  tracker_id: ''
  # @property [Array<String>] URL list for other trackers.
  trackers: []

  # @property [Object<String, TrackerConnection>] tracker connections indexed by tracker ID.
  trackerConnections: {}

  # Create a tracker manager instance.
  #
  # @param [http.Server or https.Server] server the web server that this tracker manager will be mounted on.
  # @param [String] mountpath the mount path for this tracker manager.
  # @param [Object<String, ?>] options options from {BCDNTracker} for initialize this tracker manager.
  constructor: (server, mountpath, options) ->
    {@secret, @timeout, @tracker_id, @trackers} = options
    @info "tracker manager starting (mountpath=#{mountpath}, id=#{@tracker_id})..."

    # setup WebSocket server for tracker manager.
    super path: mountpath, server: server

    @on 'connection', (socket) =>
      # parse connect parameters and verify the shared secret, close connect if secret is invalid.
      {id, secret} = url.parse(socket.upgradeReq.url, true).query
      socket.close() unless secret is @secret

      # wrap the socket in tracker connection.
      connection = new TrackerConnection socket, id

      # exclude self since this action is handled with ACCEPT packet.
      unless id is @tracker_id
        @trackerConnections[id] = connection
        @info "tracker connected from id=#{id}..."

      # accept the tracker, give self ID to it.
      connection.accept id: @tracker_id

      # setup packet handlers for this new connection.
      @setupTrackerConnectionHandlers connection

    # once the WebSocket server starts listening, try to connects other trackers.
    @on 'listening', =>
      for trackerURL in @trackers
        do (trackerURL) =>
          # build the URL and initiate the connection.
          socket = new WebSocket "#{trackerURL}?id=#{@tracker_id}&secret=#{@secret}"
          connection = new TrackerConnection socket

          # set timer for connection timeout.
          wait = setTimeout =>
            @debug "timeout to connect to the remote tracker with id=#{@tracker_id}"
            socket.close()
          , @timeout

          # once accepted within timeout, clear the timer and register the tracker.
          socket.on 'ACCEPT', (payload) =>
            {id} = payload
            clearTimeout wait
            connection.id = id
            @trackerConnections[id] = connection
            @info "connected to tracker id=#{connection.id}..."

            # setup packet handlers for this new connection.
            @setupTrackerConnectionHandlers connection

  # Action helper that announcing a information to all trackers.
  #
  # @param [Object] info the information to be announced.
  announce: (info) ->
    msg = type: 'ANNOUNCE', payload: info
    tracker.send msg for id, tracker of @trackerConnections

  # Action helper that announcing a track information describing a peer is interested in a resource.
  #
  # @param [String] peer peer ID in track information.
  # @param [String] hash hash of the resource in track information.
  announceTrack: (peer, hash) ->
    @announce peer: peer, action: 'track', hash: hash

  # Action helper that announcing a leave information describing a peer is no longer interested in a resource.
  #
  # @param [String] peer peer ID in leave information.
  # @param [String] hash hash of the resource in leave information.
  announceLeave: (peer, hash) ->
    @announce peer: peer, action: 'leave', hash: hash

  # Action helper that announcing a close information describing a peer is disconnected.
  #
  # @param [String] peer peer ID in close information.
  announceClose: (peer) ->
    @announce peer: peer, action: 'close'

  # Action helper that passes a signal to another peer with the help of trackers.
  #
  # @param [Object] detail object containing signal details.
  passSignal: (detail) ->
    {to} = detail
    targetTracker = to.split('-')[0]
    target.signal detail if (target = @trackerConnections[targetTracker])?

  # Setup packet handlers for this new connection.
  #
  # @param [TrackerConnection] connection new tracker connection.
  setupTrackerConnectionHandlers: (connection) =>
    connection.socket.on 'ANNOUNCE', (payload) =>
      @emit 'announce', payload
    connection.socket.on 'SIGNAL', (payload) =>
      @emit 'signal', payload

  debug: logger 'TrackerManager:debug'
  info: logger 'TrackerManager:info'

exports = module.exports = TrackerManager
