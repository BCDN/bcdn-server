express = require 'express'
http = require 'http'
https = require 'https'

ExpressBCDNServer = require './ExpressBCDNServer'

exports = module.exports = class StandaloneBCDNServer
  constructor: (options, callbacks) ->
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
      callbacks(server) if callbacks

    return bcdn

