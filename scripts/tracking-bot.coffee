https = require 'https' 
http = require 'http' 

class Carrier
  @carriers =
    优寄:
      name: "优寄"
      url: "http://ushipshop.com/"
      tracking_url: "http://ushipshop.com/"
      tracking_method: "POST"
    果果:
      name: "果果快递"
      url: "http://goguoguo.com/"
      tracking_url: "http://goguoguo.com/"
      tracking_method: "POST"
    顺达:
      name: "顺达快递"
      url: "http://www.sd-ex.com/"
      tracking_url: "http://www.sd-ex.com/"
      tracking_method: "POST"
    豪杰:
      name: "豪杰速递"
      url: "http://www.hjusaexpress.com/"
      tracking_url: "http://www.hjusaexpress.com/"
      tracking_method: "POST"
    _:
      name: "快递100"
    
    
module.exports = (robot) ->
  prefix = "tracking"
  robot.hear /track (.*)|(.*)/i, (res) ->
    tracking = res.match[1].trim() + "|" + res.match[2].trim()
    key = "#{prefix}:tracking"
    data = redis.brain.get(key) || {}
    data[tracking] = "1"
    redis.brain.set(key, data)
    #var myHash = new Hash('one',[1,10,5],'two', [2], 'three',[3,30,300]);
    #do some tracking
  robot.hear /MD (.*)|(.*)/i, (res) -> #mark delivered
    tracking = res.match[1].trim() + "|" + res.match[2].trim()
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
    tracking = res.match[1].trim() + "|" + res.match[2].trim()
    note = res.match[3].trim()
    key = "#{prefix}:note:#{tracking}"
    redis.brain.set(key, note)
    robot.reply("set note of '#{tracking}' to '#{note}'")
    
  robot.hear /list carriers(.*)/i, (res) ->
    robot.logger.info "list carriers"
    carriers = Carrier.carriers
    cs = for name, carrier of carriers
        "#{name}, #{carrier.name}, #{carrier.url}"
    robot.reply(cs.join("\n"))

