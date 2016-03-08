Peer = require('bcdn').Peer
Serializable = require('bcdn').Serializable
mix = require('bcdn').mix

logger = require 'debug'

exports = module.exports = class PeerConnection extends mix Peer, Serializable
  debug: logger 'PeerConnection:debug'
  info: logger 'PeerConnection:info'
  error: logger 'PeerConnection:error'

  constructor: (key, id, token, @socket) ->
    super key, id, token, @socket
    @ip = @socket.upgradeReq.socket.remoteAddress if @socket?
    connType = if token? then 'peer' else 'ping'

    switch connType
      when 'peer'
        @socket.on 'message', (data) =>
          try
            content = @deserialize data
          catch e
            return @debug "error to deserialize: #{e}, (data=#{data})"

          # sanitize malformed messages
          return unless content.type in []

          @debug "peer has sent a message (id=#{@id}, data=#{data})"

          # emit information
          @emit content.type, content.payload

        @socket.on 'close', => @emit 'CLOSE'

      when 'ping'
        # close after ping received
        @socket.on 'ping', =>
          @debug "got ping (key=#{@key})"
          @socket.close()



  # connection helpers
  send: (msg) ->
    content = @serialize msg
    @socket.send content
    @debug "message sent to peer (key=#{@key}, id=#{@id}): #{content}"

  disconnectWithError: (msg) =>
    # 1002 - CLOSE_PROTOCOL_ERROR for WebSocket
    content = @serialize type: 'ERROR', payload: msg: msg
    @socket.close 1002, content



  # action helpers
  updateContents: (contents) -> @send type: 'UPDATE', payload: contents
  accept:                    -> @send type: 'JOINED', payload: id: @id

