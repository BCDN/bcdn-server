express = require 'express'
Proto = require './server'
http = require 'http'
https = require 'https'

class ExpressBCDNServer
  constructor: (server, options) ->
    app = express()

    app.on 'mount', ->
      app._bcdn = new Proto app, server, options

    return app

class BCDNServer
  constructor: (options, callbacks) ->
    app = express()

    default_options =
      path: '/'
      port: 80
    default_options extends options

    {path, port} = options

    if options.ssl
      server = https.createServer options.ssl, app
    else
      server = http.createServer app

    bcdn = ExpressBCDNServer(server, options)
    app.use path, bcdn

    server.listen port, ->
      callbacks(server) if callbacks

    return bcdn

exports = module.exports =
  BCDNServer: BCDNServer
  ExpressBCDNServer: ExpressBCDNServer
