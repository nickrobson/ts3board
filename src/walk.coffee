fs = require 'fs'
path = require 'path'
events = require 'events'

# Recursively walks a filesystem tree, emitting what it finds.
# The EventEmitter produces the following events:
#  ('file', pathname) for each file discovered.
#  ('dir',  pathname) for each directory discovered.
#  ('end') when traversal is complete.
walk = (pathname) ->
  ee = new events.EventEmitter

  # outstanding, closureCreated, and closureCompleted provide reference counting
  # of the EventEmitter ee.  This lets us determine the right moment to emit
  # the 'end' event.
  outstanding = 0

  closureCreated = (count = 1) ->
    outstanding += count

  closureCompleted = ->
    outstanding--
    if outstanding == 0 then ee.emit 'end'

  # Recursion helper function that does the real work
  helper = (pathname) ->
    ee.emit 'dir', pathname
    closureCreated()

    fs.readdir pathname, (err, children) ->
      if children
        closureCreated(children.length)
        children.forEach (child) ->
          childpath = path.join(pathname, child)
          closureCreated()
          fs.stat childpath, (err, stat) ->
            if stat and stat.isDirectory()
              helper childpath
            else
              ee.emit 'file', childpath
            closureCompleted()
          closureCompleted()
      closureCompleted()

  # Kick off recursion and return
  helper pathname
  return ee

files = (pathname) ->
  ee = walk pathname
  filtered = new events.EventEmitter

  ee.on 'file', (pathname) -> filtered.emit 'file', pathname
  ee.on 'end', -> filtered.emit 'end'

  return filtered

module.exports = {
  all: walk
  files: files
}