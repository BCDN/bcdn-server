fs = require 'fs'

logger = require 'debug'

Contents = require('bcdn').Contents

exports = module.exports = class ContentsFile extends Contents
  debug: logger 'ContentsFile:debug'

  # TODO: setup update listener using inotify

  deserialize: (directory, cb) ->
    @debug "update contents from #{directory}..."
    # check timestamp
    fs.readFile "#{directory}/timestamp", 'utf8', (err, data) =>
      throw "error occurs while reading timestamp" if err?

      newTimestamp = parseInt data
      if newTimestamp > @timestamp
        @debug "found new contents from #{directory} " +
               "(#{@timestamp} => #{newTimestamp})"

        # update contents
        fs.readFile "#{directory}/contents", 'utf8', (err, data) =>
          throw "error occurs while reading contents" if err?

          # parse contents file
          newResouces = {}
          for line in data.split '\n'
            tokens = line.split ' '

            # parse path
            path = tokens[0]
            auto = false

            # ignore invalid path
            continue if path is ''

            # check for auto load
            if path.startsWith '!'
              path = path.substr 1
              auto = true

            # create new entry
            newResouces[path] =
              size: parseInt tokens[1]
              hash: tokens[2]
              auto: auto

          @timestamp = newTimestamp
          @resources = newResouces

          @debug "notify contents update for #{directory}..."
          cb()
