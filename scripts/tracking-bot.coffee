https = require 'https' 
http = require 'http' 

module.exports = (robot) ->
  prefix = "tracking"
  robot.hear /track (.*)|(.*)/i, (res) ->
    tracking = res.match[1] + "|" + res.match[2]
    key = "#{prefix}:tracking"
    data = redis.brain.get(key) || {}
    data[tracking] = "1"
    redis.brain.set(key, data)
    #var myHash = new Hash('one',[1,10,5],'two', [2], 'three',[3,30,300]);
    #do some tracking
  robot.hear /MD (.*)|(.*)/i, (res) -> #mark delivered
    tracking = res.match[1] + "|" + res.match[2]
    key = "#{prefix}:tracking"
    data = redis.brain.get(key) || {}
    #data.remove
    redis.brain.set(key, data)
    key = "#{prefix}:delivered"
    data = redis.brain.get(key) || {}
    data[tracking] = "2"
    redis.brain.set(key, data)
    #
  robot.hear /refresh status(.*)/i, (res) ->
    key = "#{prefix}:tracking"
    data = redis.brain.get(key) || {}
    for tracking, _ of data
      #
      key = "#{prefix}:status:#{tracking}"
      status = redis.brain.get(key) || {}
      
      #
  robot.hear /note (.*)|(.*) (.*)/i, (res) ->
    tracking = res.match[1] + "|" + res.match[2]
    key = "#{prefix}:note:#{tracking}"
    redis.brain.set(key, res.match[3])
    
  robot.hear /list carriers(.*)/i, (res) ->
    robot.logger.info "list carriers"
    
   
