fs           = require 'fs'
http         = require 'http'
dgram        = require 'dgram'
walk         = require './walk'
express      = require 'express'
socketio     = require 'socket.io'
passport     = require 'passport'
passporthttp = require 'passport-http'
Strategy     = passporthttp.DigestStrategy

try
   config = JSON.parse (fs.readFileSync __dirname + '/config.json')
catch err
   if err.message.indexOf('ENOENT') != -1
      throw new Error 'It looks like you don\'t have a config.json!'
   if err instanceof SyntaxError
      throw new Error 'It looks like your config.json has invalid JSON!'
   throw new Error err

app    = express()
server = http.Server app
io     = socketio server
port   = config.port or 1337

[playlist, tracks, gvol, isPlaying, current, skip, users, volume] = [[], [], 50, 0, -1, false, 0, 50]

cmdSocket = dgram.createSocket 'udp4'
recSocket = dgram.createSocket 'udp4'

try
   recSocket.bind config.recv_port
   server.listen port, ->
      console.log 'Listening on *:' + port
catch err
   throw new Error 'Failed to bind to port! Perhaps ' + port + ' is already in use?'

recSocket.on 'message', (msg) ->
   console.log 'Notification from TS3 Client: ' + msg
   if playlist.length > 0 and not skip
      console.log 'Playing next.'
      isPlaying = false
      track     = playlist.shift()
      # console.log JSON.stringify(track)
      playid track.id, true, true
      isPlaying = true
      current   = track.id
   else if not skip
      isPlaying = false
   skip = false

shuffle = (array) ->
   [m, t, i] = [array.length, 0, 0]
   while m
      i = Math.floor Math.random() * m--
      [array[m], array[i]] = [array[i], array[m]]
   return array

setvol = (vol) ->
   gvol = Math.max 0, Math.min 100, vol
   console.log 'Changing volume to ' + gvol
   cmd  = new Buffer '/volume ' + gvol
   cmdSocket.send cmd, 0, cmd.length, config.send_port, config.send_host

playid = (id, remote, repeat) ->
   try
      if id < 0 or id >= tracks.length
         console.log 'Invalid track'
         return
      track = tracks[id]
      # console.log 'tracks[' + id + '] = ' + JSON.stringify(track)
      if not remote and not repeat
         for trk in playlist
            if id == trk.id
               return
      if isPlaying
         playlist.push { name: track.name, id: track.id }
      else
         [isPlaying, current] = [true, id]
         cmd = new Buffer '/music ' + track.file
         cmdSocket.send cmd, 0, cmd.length, config.send_port, config.send_host
   catch err
      console.log err.name + ': ' + err.message
      throw err

getFriendlyName = (name) ->
   if name.startsWith config.basePath
      name = name.substring config.basePath.length, name.lastIndexOf('.')
   return name.replace /\//g, ' / '

reloadFiles = ->
   ee = walk.files config.basePath
   found_tracks = []
   ee.on 'file', (file) ->
      file = file.trim()
      if file.endsWith('.mp3') or file.endsWith('.wav')
         found_tracks.push file
   ee.on 'end', ->
      found_tracks.sort(
         (a, b) ->
            return a.toLowerCase().localeCompare(b.toLowerCase())
      )
      for file in found_tracks
         tracks.push { id: tracks.length, name: getFriendlyName(file), file: file }

hasperm = (req, perm, main) ->
   if not req or not perm
      return false
   if req.user.permissions[perm]
      return true
   if not main? and req.user.permissions.main
      return true
   return false

stop = ->
   cmd = new Buffer '/stop'
   cmdSocket.send cmd, 0, cmd.length, config.send_port, config.send_host

if typeof String.prototype.endsWith != 'function'
   String.prototype.endsWith = (suffix) ->
     return @indexOf(suffix, @length - suffix.length) != -1;

reloadFiles()

finduser = (username, cb) ->
   process.nextTick ->
      if config.users and config.users[username] and config.users[username].password and config.users[username].permissions
         return cb null, config.users[username]
      return cb null, null

passport.use new Strategy { qop: 'auth' }, (username, cb) ->
   finduser username, (err, user) ->
      if err
         return cb err
      if not user
         return cb null, false
      return cb null, user, user.password

io.on 'connection', (socket) ->
   io.emit 'user change', ++users
   io.emit 'setvolume', gvol
   socket.emit 'refreshList'
   console.log 'Users: ' + users
   socket.on 'disconnect', ->
      --users
      users = Math.max 0, users
      io.emit 'user change', ' ' + users + ' '
      console.log 'Users: ' + users
   socket.on 'changevolume', (volume) ->
      socket.broadcast.emit 'setvolume', volume
      setvol volume

app.use passport.authenticate 'digest', { session: false }
app.use express.static 'public'
app.set 'view engine', 'pug'
app.locals.pretty = true

app.get '/', (req, res) ->
  res.render 'index', {}

app.get '/backend/tracks', (req, res) ->
   if not hasperm req, 'view'
      res.send 403, 'Not allowed.'
      return
   res.setHeader 'Content-Type', 'application/json'
   result = []
   for track in tracks
      result.push track.name
   res.end JSON.stringify result

app.get '/backend/playing', (req, res) ->
   if not hasperm req, 'view'
      res.send 403, 'Not allowed.'
      return
   res.setHeader 'Content-Type', 'application/json'
   if isPlaying and tracks[current]
      res.end JSON.stringify tracks[current].name
   else
      res.end JSON.stringify false

app.get '/backend/playlist', (req, res) ->
   if not hasperm req, 'view'
      res.send 403, 'Not allowed.'
      return
   res.setHeader 'Content-Type', 'application/json'
   res.end JSON.stringify(playlist.map (e) -> e.name)

app.post '/backend/shuffle', (req, res) ->
   if not hasperm req, 'shuffle'
      res.send 403, 'Not allowed.'
      return
   shuffle playlist
   res.end()

app.post '/backend/stop', (req, res) ->
   if not hasperm req, 'stop'
      res.send(403, 'Not allowed.')
      return
   [skip, isPlaying] = [false, false]
   stop()
   res.end()

app.post '/backend/skipleft', (req, res) ->
   if not hasperm req, 'skip'
      res.send 403, 'Not allowed.'
      return
   if not isPlaying or not tracks[current]
      return
   stop()
   [skip, isPlaying] = [false, false]
   playid current, false
   isPlaying = true
   res.end()

app.post '/backend/skipright', (req, res) ->
   if not hasperm req, 'skip'
      res.send 403, 'Not allowed.'
      return
   [skip, isPlaying] = [false, false]
   stop()
   if playlist.length > 0
      track = playlist.shift()
      playid track.id, false, true
   skip = false
   res.end()

app.post '/backend/clear', (req, res) ->
   if not hasperm req, 'clear', true
      res.send 403, 'Not allowed.'
      return
   playlist = []
   res.end()

app.post '/backend/reload', (req, res) ->
   if not hasperm req, 'reload', true
      res.send 403, 'Not allowed.'
      return
   [tracks, playlist] = [[], []]
   reloadFiles()
   res.end()

app.post '/backend/restart', (req, res) ->
   if not hasperm req, 'restart', true
      res.send 403, 'Not allowed.'
      return
   console.log 'Shutting down.'
   res.end()
   process.exit(0)

app.post '/backend/play/:id', (req, res) ->
   if not hasperm req, 'queue'
      res.send 403, 'Not allowed.'
      return
   try
      id = parseInt req.params.id
      console.log 'Playing ' + tracks[id].name
      playid id, false, req.user.permissions.repeat
   catch err
      console.log err.name + ': ' + err.message
      res.send 400, 'ID is not a number'

   res.end()

app.post '/backend/unqueue/:id', (req, res) ->
   if not hasperm req, 'unqueue'
      res.send 403, 'Not allowed.'
      return
   console.log 'Removing ' + playlist[req.params.id].name
   id = parseInt req.params.id
   if id < 0 or id >= playlist.length
      res.end (JSON.stringify false)
   else
      playlist.splice id, 1
      res.end (JSON.stringify true)

