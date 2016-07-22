express = require 'express'
http = require 'http'
https = require 'https'

ExpressBCDNServer = require './ExpressBCDNServer'

# A standalone BCDN tracker.
class StandaloneBCDNServer

  # Create a standalone BCDN tracker instance.
  #
  # @param [Object] options see {BCDNTracker#constructor}.
  # @param [Function] callback function called when server starts listening.
  # @option callback [WebServer] server the server that tracker is mounted on.
  constructor: (options, callback) ->
    app = express()

    default_options =
      host: '127.0.0.1'
      path: '/'
      port: 80
    default_options extends options

    {path, host, port} = options

    if options.ssl
      server = https.createServer options.ssl, app
    else
      server = http.createServer app

    bcdn = ExpressBCDNServer(server, options)
    app.use path, bcdn

    server.listen port, host, ->
      callback(server) if callback

    return bcdn

exports = module.exports = StandaloneBCDNServer
