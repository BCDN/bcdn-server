querystring = require 'querystring'
WebSocket = require 'ws'

Serializable = require('bcdn').Serializable
mix = require('bcdn').mix

logger = require 'debug'

exports = module.exports = class TrackerConnection extends mix Serializable
  debug: logger 'TrackerConnection:debug'
  info: logger 'TrackerConnection:info'

  constructor: (@socket, @id = null) ->
    @socket.on 'message', (data) =>
      try
        content = @deserialize data
      catch e
        return @debug "error to deserialize: #{e}, (data=#{data})"

      # sanitize malformed messages
      return unless content.type in ['ACCEPT']

      @debug "got a message from tracker (id=#{@id}, data=#{data})"

      # emit information
      @socket.emit content.type, content.payload

    @socket.on 'close', =>
      @info "tracker left (id=#{@id})"

    @socket.on 'error', (error) =>
      @debug "error on connect tracker - #{error}"

  # connection helpers
  send: (msg) ->
    content = @serialize msg
    @socket.send content
    @debug "message sent to tracker (id=#{@id}): #{content}"

  # action helpers
  accept: (tracker_id) -> @send type: 'ACCEPT', payload: id: tracker_id
