module.exports = (robot) ->
  #robot.router.get '/', (req, res) ->
    #res.send 'OK'

  robot.router.all '/twitter/oauth/:user', (req, res) ->
    #room   = req.params.room
    user  = req.params.user
    #data   = JSON.parse req.body.payload
    #secret = data.secret
    #robot.messageRoom room, "I have a secret: {secret}"
    #res.send 'OK'
    robot.messageRoom 'random', "#{req.query.message}"

  robot.hear /who am I.*/i, (res) ->
    user = res.message.user  
    #room = res.message.room
    room = robot.adapter.client.rtm.dataStore.getDMByName res.message.user.name
    robot.reply {room: room.id , user: user}, "you are #{user.id}" 
