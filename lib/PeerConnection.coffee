Peer = require('bcdn').Peer
Serializable = require('bcdn').Serializable
mix = require('bcdn').mix

logger = require 'debug'

# Wrapper for WebSocket connection from peer.
#
# @extend Peer
# @extend Serializable
class PeerConnection extends mix Peer, Serializable
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
            return @error "EE error to deserialize: #{e}, (data=#{data})"

          # sanitize malformed messages.
          return unless content.type in ['DOWNLOAD', 'SIGNAL', 'FETCH']

          @debug "<P peer has sent a message (id=#{@id}, data=#{data})"

          # emit information.
          @emit content.type, content.payload

        @socket.on 'close', => @emit 'CLOSE'

      when 'ping'
        # close after ping received.
        @socket.on 'ping', =>
          @info "!P got ping (key=#{@key})"
          @socket.close()

  # Connection helper that sends a message to peer.
  #
  # @param [Object] msg message object.
  send: (msg) ->
    content = @serialize msg
    @socket.send content
    @debug ">P message sent to peer (key=#{@key}, id=#{@id}): #{content}"

  # Connection helper that disconnect the connection with a error message.
  #
  # @param [Object] msg message object.
  disconnectWithError: (msg) ->
    # 1002 - CLOSE_PROTOCOL_ERROR for WebSocket
    content = @serialize type: 'ERROR', payload: msg: msg
    @socket.close 1002, content

  # Action helper that accepts a peer.
  accept: ->
    @info ">P [msg=JOINED]: send JOINED packet to peer[id=#{@id}]"
    @send type: 'JOINED', payload: id: @id

  # Action helper that pushes the contents to peer.
  #
  # @param [String] contents serialized contents object.
  updateContents: (contents) ->
    @info ">P [msg=UPDATE]: send UPDATE packet to peer[id=#{@id}]"
    @send type: 'UPDATE', payload: contents

  # Action helper that sends resource information to peer.
  #
  # @param [Object] info information that contains resource hash, pieces hashes, and candidates for the resources.
  sendResourceInfo: (info) ->
    @info ">P [msg=RESOURCE]: send RESOURCE packet to peer[id=#{@id}] " +
          "for resource[hash=#{info.hash}]"
    @send type: 'RESOURCE', payload: info

  # Action helper that passes signal packet to peer.
  #
  # @param [Object] detail the signal packet.
  signal: (detail) ->
    @info ">P [msg=SIGNAL]: send SIGNAL packet to peer[id=#{@id}] " +
          "from peer[id=#{detail.from}]"
    @send type: 'SIGNAL', payload: detail

  debug: logger 'PeerConnection:debug'
  info: logger 'PeerConnection:info'
  error: logger 'PeerConnection:error'

exports = module.exports = PeerConnection
