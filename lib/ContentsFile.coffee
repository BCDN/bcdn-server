fs = require 'fs'

Contents = require('bcdn').Contents

logger = require 'debug'

# Contents wrapper for reading contents from file.
#
# @extend Contents
class ContentsFile extends Contents
  # Override deserialize method to load Contents from file.
  #
  # @param [String] directory the directory that contains the timestamp file and the contents file.
  # @param [Function] cb the callback function which is invoked after contents loaded.
  deserialize: (directory, cb) ->
    # future work: setup update listener using inotify so the latest contents will be pushed to peer node.
    @info "-- update contents from #{directory}..."
    # check timestamp
    fs.readFile "#{directory}/timestamp", 'utf8', (err, data) =>
      throw "error occurs while reading timestamp" if err?

      newTimestamp = parseInt data
      if newTimestamp > @timestamp
        @info "-- found new contents from #{directory} " +
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

            # ignore invalid path
            continue if path is ''

            # create new entry
            newResouces[path] =
              size: parseInt tokens[1]
              hash: tokens[2]

          @timestamp = newTimestamp
          @resources = newResouces

          @info "-- notify contents update for #{directory}..."
          cb()

  info: logger 'ContentsFile:info'

exports = module.exports = ContentsFile
