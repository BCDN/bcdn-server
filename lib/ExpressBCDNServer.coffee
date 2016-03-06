express = require 'express'
Tracker = require './Tracker'

exports = module.exports = class ExpressBCDNServer
  constructor: (server, options) ->
    app = express()

    app.on 'mount', ->
      app._bcdnTracker = new Tracker app, server, options
      app._bcdnTracker.start()

    return app

