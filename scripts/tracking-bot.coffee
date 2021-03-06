https = require 'https' 
http = require 'http' 
hashes = require('hashes')

class SimpleSet
  @BLANK = ""
  constructor: (data) ->
    if data
      @data = data
    else
      @data = {}
  add: (obj) ->
    @data[obj] = HashSet.BLANK
  remove: (obj) ->
    delete @data[obj]
  contains: (obj) ->
    #TODO
    return true
  #square = (x) -> x * x
  @load = (d) ->
    if(d && d["data"])
      new HashSet(d["data"])
    else
      new HashSet
    

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
      url: "http://www.kuaidi100.com/"
  
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
  robot.hear /track (.*)[|](.*)/i, (res) ->
    tracking = res.match[1].trim() + "|" + res.match[2].trim()
    key = "#{prefix}:tracking"
    data = SimpleSet.load(robot.brain.get(key))# || new HashSet
    robot.logger.info  data
    data.add(tracking)
    robot.brain.set(key, data)
    res.reply("I'm tracking #{tracking}...\n")


  robot.hear /MD (.*)[|](.*)/i, (res) -> #mark delivered
    tracking = res.match[1].trim() + "|" + res.match[2].trim()
    key = "#{prefix}:tracking"
    data = SimpleSet.load(robot.brain.get(key))
    data.remove(tracking)
    robot.logger.info data
    robot.brain.set(key, data)
    key = "#{prefix}:delivered\n"
    data = SimpleSet.load(robot.brain.get(key))
    data.add(tracking)
    robot.brain.set(key, data)
    res.reply("#{tracking} has been delivered.")
    #

  robot.hear /refresh status(.*)/i, (res) ->
    key = "#{prefix}:tracking"
    data = robot.brain.get(key) || {}
    for tracking, _ of data
      #
      key = "#{prefix}:status:#{tracking}"
      status = robot.brain.get(key) || {}
      res.reply("#{tracking} is #{status}")
      #
  robot.hear /note (.*)[|](.*) (.*)/i, (res) ->
    tracking = res.match[1].trim() + "|" + res.match[2].trim()
    note = res.match[3].trim()
    key = "#{prefix}:note:#{tracking}"
    robot.brain.set(key, note)
    res.reply("set note of '#{tracking}' to '#{note}'\n")
    
  robot.hear /list carriers(.*)/i, (res) ->
    robot.logger.info "list carriers"
    carriers = Carrier.carriers
    cs = for name, carrier of carriers
        "#{name}, #{carrier.name}, #{carrier.url}"
    res.reply(cs.join("\n"))

