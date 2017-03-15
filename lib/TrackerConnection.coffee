querystring = require 'querystring'
WebSocket = require 'ws'

Serializable = require('bcdn').Serializable

logger = require 'debug'

# WebSocket wrapper for tracker connection.
#
# @extend Serializable
class TrackerConnection extends Serializable
  # @property [WebSocket] socket instance of WebSocket connection.
  socket: null
  # @property [String] ID of the partner tracker.
  id: null

  # Create a tracker connection instance with a WebSocket.
  #
  # @param [Object<String, ?>] options options from {BCDNPeer} for initialize this tracker connection.
  # @param [String] id ID of the tracker for the connection.
  constructor: (@socket, @id = null) ->
    @socket.on 'message', (data) =>
      try
        content = @deserialize data
      catch e
        return @error "EE error to deserialize: #{e}, (data=#{data})"

      # sanitize malformed messages
      return unless content.type in ['ACCEPT', 'ANNOUNCE', 'SIGNAL']

      @debug "<T got a message from tracker (id=#{@id}, data=#{data})"

      # emit information
      @socket.emit content.type, content.payload

    # FIXME: handle TrackerConnection close in TrackerManager
    @socket.on 'close', =>
      @info "*T tracker left (id=#{@id})"

    @socket.on 'error', (error) =>
      @error "EE error on connect tracker - #{error}"

  # Connection helper that sends a message to tracker.
  #
  # @param [Object] msg message object.
  send: (msg) ->
    content = @serialize msg
    @socket.send content
    @debug ">T message sent to tracker (id=#{@id}): #{content}"

  # Action helper that accepts a tracker.
  #
  # @param [String] tracker ID of the current tracker itself.
  accept: (tracker) ->
    @info ">T [msg=ACCEPT]: send ACCEPT packet to tracker[id=#{@id}]"
    @send type: 'ACCEPT', payload: tracker

  # Action helper that routes a signal packet to another tracker.
  #
  # @param [Object] detail the signal packet.
  signal: (detail) ->
    @info ">T [msg=SIGNAL]: send SIGNAL packet to tracker[id=#{@id}] " +
          "for peer[id=#{detail.to}] from peer[id=#{detail.from}]"
    @send type: 'SIGNAL', payload: detail

  debug: logger 'TrackerConnection:debug'
  info: logger 'TrackerConnection:info'
  error: logger 'TrackerConnection:error'

exports = module.exports = TrackerConnection
