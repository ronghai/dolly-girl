https = require 'https' 
http = require 'http' 

class Carrier
  @carriers =
    优寄:
      name: "优寄"
      url: "http://ushipshop.com/"
      trackingURI: "http://www.ushipshop.com/search/search/index"
      postData: "number=%@"
      method: "POST"
      order: "asc"
    果果:
      name: "果果快递"
      url: "http://goguoguo.com/"
      trackingURI: "http://www.goguoguo.com/track.html"
      postData: "data=%@"
      method: "POST"
      order: "desc"
    顺达:
      name: "顺达快递"
      url: "http://www.sd-ex.com/"
      trackingURI: "http://www.sd-ex.com/cgi-bin/GInfo.dll?EmmisTrack"
      postData: "cno=%@&ntype=1"
      method: "POST"
    豪杰:
      name: "豪杰速递"
      url: "http://www.hjusaexpress.com/"
      trackingURI: "http://www.hjusaexpress.com/result.aspx?txtNo=%@"
      postData: "txtNo=%@"
      method: "POST"
    _:
      name: "快递100"
  
  @track = (tracking, callback) ->
    t_c = tracking.split("|")
    carrier = Carrier.carriers[t_c[1]] ?= Carrier.carriers["_"]
    postData = carrier.postData
    options = 
      hostname : host
      host : host
      method : carrier.method
      headers : 
        'Accept' : '*/*'
        'Content-Length' : if postData? then Buffer.byteLength(postData) else 0
        'Content-Type' : 'application/x-www-form-urlencoded'
    options.agent = new https.Agent(options)
    req = https.request options, (res) ->
      res.on 'data', (chunk) ->
        console.log chunk
        callback? chunk
      res.on 'error', (e) ->
        console.log e.message
    if postData?
      req.write(postData)
    req.end()
    
    
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

