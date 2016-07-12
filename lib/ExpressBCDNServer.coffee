express = require 'express'

BCDNTracker = require './BCDNTracker'

exports = module.exports = class ExpressBCDNServer
  constructor: (server, options) ->
    app = express()
    app.on 'mount', ->
      app._bcdnTracker = new BCDNTracker server, app.mountpath, options
    return app
