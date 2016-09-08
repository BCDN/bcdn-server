Peer = require('bcdn').Peer
Serializable = require('bcdn').Serializable
mix = require('bcdn').mix

logger = require 'debug'

# Wrapper for WebSocket connection from peer.
class PeerConnection extends mix Peer, Serializable
  verbose: logger 'PeerConnection:verbose'
  debug: logger 'PeerConnection:debug'
  info: logger 'PeerConnection:info'
  error: logger 'PeerConnection:error'

  # @property [WebSocket] socket instance of WebSocket connection.
  socket: null
  # @property [String] peer IP.
  ip: null

  # Create a peer connection instance.
  #
  # @param [Object<String, ?>] properties properties for Peer data model.
  # @param [WebSocket] socket socket instance of WebSocket connection.
  constructor: (properties, @socket) ->
    super properties

    # extract peer IP from socket.
    @ip = @socket.upgradeReq.socket.remoteAddress if @socket?

    # setup handlers for this connection based on connection type.
    connType = if @token? then 'peer' else 'ping'
    switch connType
      when 'peer'
        @socket.on 'message', (data) =>
          try
            content = @deserialize data
          catch e
            return @debug "error to deserialize: #{e}, (data=#{data})"

          # sanitize malformed messages.
          return unless content.type in ['DOWNLOAD', 'SIGNAL', 'FETCH']

          @verbose "peer has sent a message (id=#{@id}, data=#{data})"

          # emit information.
          @emit content.type, content.payload

        @socket.on 'close', => @emit 'CLOSE'

      when 'ping'
        # close after ping received.
        @socket.on 'ping', =>
          @debug "got ping (key=#{@key})"
          @socket.close()

  # Connection helper that sends a message to peer.
  #
  # @param [Object] msg message object.
  send: (msg) ->
    content = @serialize msg
    @socket.send content
    @verbose "message sent to peer (key=#{@key}, id=#{@id}): #{content}"

  # Connection helper that disconnect the connection with a error message.
  #
  # @param [Object] msg message object.
  disconnectWithError: (msg) ->
    # 1002 - CLOSE_PROTOCOL_ERROR for WebSocket
    content = @serialize type: 'ERROR', payload: msg: msg
    @socket.close 1002, content

  # Action helper that accepts a peer.
  accept:                     -> @send type: 'JOINED',    payload: id: @id

  # Action helper that pushes the contents to peer.
  #
  # @param [String] contents serialized contents object.
  updateContents: (contents)  -> @send type: 'UPDATE',    payload: contents

  # Action helper that sends resource information to peer.
  #
  # @param [Object] info information that contains resource hash, pieces hashes, and candidates for the resources.
  sendResourceInfo: (info)    -> @send type: 'RESOURCE',  payload: info

  # Action helper that passes signal packet to peer.
  #
  # @param [Object] detail the signal packet.
  signal: (detail)            -> @send type: 'SIGNAL',    payload: detail

exports = module.exports = PeerConnection
