https = require 'https' 
QUERY_STRING = require('querystring')
HttpClient = require('scoped-http-client')
FS = require('fs')
CryptoJS = require('crypto-js')
crypto = require('crypto')

class TwitterOAuth
  @HEX : '0123456789ABCDEF'
  @URL:{
    BASE: "api.twitter.com",
    REQUEST: "https://api.twitter.com/oauth/request_token",
    REQUEST_PATH : "/oauth/request_token",
    ACCESS: "https://api.twitter.com/oauth/access_token",
    ACCESS_PATH: "/oauth/access_token"
    AUTHORIZE: "https://api.twitter.com/oauth/authorize",
    POST_PATH: "/1.1/statuses/update.json",
    POST: "https://api.twitter.com/1.1/statuses/update.json",
  }
  constructor: (@_options={ consumer_key:"", consumer_secret_key:"", callback:"", access_token:"", access_token_secret:"" }) ->
    @consumer_key = @_options["consumer_key"]
    @consumer_secret_key = @_options["consumer_secret_key"]
    @callback = @_options["callback"]
    @access_token = @_options["access_token"]
    @access_token_secret = @_options["access_token_secret"]
  
  extend:(obj, sources...) ->
    for source in sources
      obj[key] = value for own key, value of source
    obj
  
  hex: ->
    TwitterOAuth.HEX[Math.floor(Math.random() * 16)]
  
  oauth_nonce: (bits = 32) ->
    return crypto.randomBytes(Math.ceil(bits*3/4))
      .toString("base64").slice(0, bits)
      .replace(/\+/g, '0').replace(/\//g, '0')
  
  
  sort_options: (options =[]) ->
    options.sort (a, b)->
      a[0] < b[0] ? -1 : (a[0] > b[0] ? 1 : 0)
    options.reverse();
    options

  join_options: (options = [], joiner=", ", hasQ=true) ->
    st = []
    for kv in options
      if kv[1]? && kv[1] != ""
        if hasQ
          st.push "#{kv[0]}=\"#{encodeURIComponent(kv[1])}\""
        else
          st.push "#{kv[0]}=#{encodeURIComponent(kv[1])}"
    st.join(joiner)

  oauth_params: (sources...)->
    options = [
      ["oauth_consumer_key" , @consumer_key],
      ["oauth_nonce", @oauth_nonce()],
      ["oauth_signature_method" , "HMAC-SHA1"],
      ["oauth_timestamp" , Math.floor(Date.now() / 1000)],
      ["oauth_version" , "1.0"],
      ["oauth_token" , @access_token]
    ]
    for source in sources
      options.push source
    options

  log:(o) ->
    console.log(o)
    
  extend_list:(obj, sources...) ->
    for source in sources
      for el in source
        obj.push el
    obj
 
  signature: (sign_data = [], url='', method = 'POST', csonly = false) ->
    sign_data = @sort_options sign_data
    sign_data = @join_options sign_data, '&', false
    sb = "#{method.toUpperCase()}&"+encodeURIComponent(url)
    sb = sb + "&" + encodeURIComponent(sign_data)
    key = @consumer_secret_key+"&"
    unless csonly
      key += @access_token_secret
    @log("do signing...")
    @log(sb)
    @log(key)
    signature = CryptoJS.enc.Base64.stringify(CryptoJS.HmacSHA1(sb, key))
    signature

  post: (host, path, oauth_data, post_data, callback) ->
    options = 
      hostname : host
      host : host
      port : 443
      path : path
      method : 'POST'
      headers : 
        'Accept' : '*/*'
        'Content-Length' : if post_data? then Buffer.byteLength(post_data) else 0
        'Content-Type' : 'application/x-www-form-urlencoded'
        'Authorization' : oauth_data
    options.agent = new https.Agent(options)
    req = https.request options, (res) ->
      res.on 'data', (chunk) =>
        @log chunk+""
        callback? chunk
      res.on 'error', (e) =>
        @log e.message
    if post_data?
      req.write(post_data)
    req.end()

  authorization: (oauth_headers=[], sign) ->
    oauth_headers.push ["oauth_signature", sign]  if sign?
    oauth_headers = @sort_options oauth_headers
    oauth_data = @join_options oauth_headers, ", ", true
    oauth_data = "OAuth #{@oauth_data}"
    @log(oauth_data)
    oauth_data

  request_token: (callback) ->
    oauth_headers = @oauth_params(["oauth_callback", @callback])
    sign = @signature(@extend_list([], oauth_headers), TwitterOAuth.URL.REQUEST, "POST", true)
    oauth_data = @authorization(oauth_headers, sign)
    @post TwitterOAuth.URL.BASE, TwitterOAuth.URL.REQUEST_PATH, oauth_data, null, (chunk) =>
      @log chunk+""
      dt = QUERY_STRING.parse(chunk+"")
      @access_token_secret = dt["oauth_token_secret"]
      @access_token = dt["oauth_token"]
      callback?@, "#{TwitterOAuth.URL.AUTHORIZE}?oauth_token=#{@access_token}"

  access_token: (@access_token, @access_token_secret, @oauth_verifier, callback) ->
    oauth_headers = @oauth_params()
    post_data = [["oauth_verifier", @oauth_verifier]]
    sign = @signature(@extend_list(post_data, oauth_headers), TwitterOAuth.URL.ACCESS, "POST", false)
    oauth_data = @authorization(oauth_headers, sign)

    @post TwitterOAuth.URL.BASE, TwitterOAuth.URL.ACCESS, oauth_data, @join_options(post_data, '&', false), (chunk) =>
      @log "access_token"
      @log chunk+""
      dt = QUERY_STRING.parse(chunk+"")
      @access_token_secret = dt["oauth_token_secret"]
      @access_token = dt["oauth_token"]
      callback?@

  tweet: (t) ->
    oauth_headers = @oauth_params()
    post_data = [["status", t]]
    sign = @signature(@extend_list(post_data, oauth_headers), TwitterOAuth.URL.POST, "POST", false)
    oauth_data = @authorization(oauth_headers, sign)
    @post TwitterOAuth.URL.BASE, TwitterOAuth.URL.POST+'?'+@join_options(post_data, '&', false), oauth_data,  null, (chunk) =>
      @log "access_token"
      @log chunk+""
      callback?@

TWITTER_CONSUMER_KEY = process.env.TWITTER_CONSUMER_KEY
TWITTER_CONSUMER_SECERT_KEY = process.env.TWITTER_CONSUMER_SECERT_KEY
TWITTER_CALLBACK_URL = process.env.TWITTER_CALLBACK_URL

module.exports = (robot) -> 

  robot.respond /twitter (.*)/i, (res) ->
    tweet = res.match[1]
    user = res.message.user
    access_token = robot.brain.get "#{user.id}:twitter:access_token"
    access_token_secret = robot.brain.get "#{user.id}:twitter:access_token_secret" 
    if access_token?
      oauth = new TwitterOAuth({consumer_key:TWITTER_CONSUMER_KEY,consumer_secret_key:TWITTER_CONSUMER_SECERT_KEY, 
                  access_token:access_token, access_token_secret:access_token_secret})
      res.reply "I'm posting that tweet: #{tweet}"
       #tweet with oauth
    else
      robot.brain.set("#{user.id}:twitter:draft", tweet)
      oauth = new TwitterOAuth({consumer_key:TWITTER_CONSUMER_KEY, consumer_secret_key:TWITTER_CONSUMER_SECERT_KEY, callback: TWITTER_CALLBACK_URL})
      oauth.request_token (oa, verify_url) =>
        robot.brain.set("#{user.id}:twitter:access_token_t", oa.access_token)
        robot.brain.set("#{user.id}:twitter:access_token_secret_t", oa.access_token_secret)
        robot.brain.set("twitter:#{oa.access_token}", user)
        room = robot.adapter.client.rtm.dataStore.getDMByName user.name
        res.reply "Please go to DM and click the link"
        robot.reply {room:room.id, user: user}, "Please click the following url to authorize your twitter account\n#{verify_url}"
    
  robot.respond /clear twitter account/i, (res) ->
    user = res.message.user
    robot.brain.remove "#{user.id}:twitter:access_token"
    robot.brain.remove "#{user.id}:twitter:access_token_secret"
    res.reply "Twitter's oAuth has been removed"
  
  robot.router.all '/twitter/oauth(/)?', (req, res) ->
    query = QUERY_STRING.parse(url.parse(req.url).query)
    access_token = query["oauth_token"]
    oauth_verifier = query["oauth_verifier"]
    user = robot.brain.get "twitter:#{access_token}"
    unless user?
      res.send 'ERROR'
      return
    access_token_secret = robot.brain.get("#{user.id}:twitter:access_token_secret_t")
    oauth = new TwitterOAuth({consumer_key:TWITTER_CONSUMER_KEY, consumer_secret_key:TWITTER_CONSUMER_SECERT_KEY, callback:TWITTER_CALLBACK_URL})
    oauth.access_token access_token, access_token_secret, oauth, (oa)=>
      robot.brain.set("#{user.id}:twitter:access_token", oa.access_token)
      robot.brain.set("#{user.id}:twitter:access_token_secret", oa.access_token_secret)
      robot.brain.remove "twitter:#{access_token}"
      robot.brain.remove "#{user.id}:twitter:access_token_t"
      robot.brain.remove "#{user.id}:twitter:access_token_secret_t" 
      draft = robot.brain.get "#{user.id}:twitter:draft"
      if draft?
        room = robot.adapter.client.rtm.dataStore.getDMByName user.name
        robot.reply {room:room.id, user: user}, "I'm posting that tweet: #{draft}"
    res.send 'OK'
   
