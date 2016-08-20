express = require 'express'

BCDNTracker = require './BCDNTracker'

# BCDN tracker as a module of Express framework.
class ExpressBCDNServer

  # Create a BCDN tracker as Express module.
  #
  # @param [http.Server or https.Server] server the web server that mounts the tracker.
  # @param [Object<String, ?>] options see {BCDNTracker#constructor}.
  constructor: (server, options) ->
    app = express()
    app.on 'mount', ->
      app._bcdnTracker = new BCDNTracker server, app.mountpath, options
    return app

exports = module.exports = ExpressBCDNServer
