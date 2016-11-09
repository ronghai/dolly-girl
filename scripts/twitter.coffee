https = require 'https' 
QUERY_STRING = require('querystring')
HttpClient = require('scoped-http-client')
FS = require('fs')
CryptoJS = require('crypto-js')
crypto = require('crypto')

class TwitterOAuth
  @HEX : '0123456789ABCDEF'
  @URL:{
    BASE_URL: "api.twitter.com",
    REQUEST_TOKEN: "https://api.twitter.com/oauth/request_token",
    ACCESS_TOKEN: "https://api.twitter.com/oauth/access_token",
    AUTHORIZE: "https://api.twitter.com/oauth/authorize",
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
  
  http: (url, options) ->
    HttpClient.create(url, @extend({}, options))
  
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

  oauth_params: ->
    options = [
      ["oauth_callback", @callback],
      ["oauth_consumer_key" , @consumer_key],
      ["oauth_nonce", @oauth_nonce()],
      ["oauth_signature_method" , "HMAC-SHA1"],
      ["oauth_timestamp" , Math.floor(Date.now() / 1000)],
      ["oauth_version" , "1.0"]
    ]
    options


  extend_list:(obj, sources...) ->
    for source in sources
      for el in source
        obj.push el
    obj
 
  signature: (post_data = [], url='', method = 'POST') ->
    post_data = @sort_options post_data
    post_data = @join_options post_data, '&', false
    sb = "#{method.toUpperCase()}&"+encodeURIComponent(url)
    sb = sb + "&" + encodeURIComponent(post_data)
    if @consumer_secret_key?
      signature = CryptoJS.enc.Base64.stringify(CryptoJS.HmacSHA1(sb, @consumer_secret_key+"&"))
      signature
    else
      null

  request_access_token: (callback) ->
    oauth_headers = @oauth_params()
    post_data = @extend_list([], oauth_headers)
    sign = @signature(post_data, TwitterOAuth.URL.REQUEST_TOKEN, "POST")
    if sign?
      oauth_headers.push ["oauth_signature", sign]
    oauth_headers = @sort_options oauth_headers
    @oauth_data = @join_options oauth_headers, ", ", true
    @oauth_data = "OAuth #{@oauth_data}"

    options = 
      hostname : TwitterOAuth.URL.BASE_URL
      host : TwitterOAuth.URL.BASE_URL
      port : 443
      path : '/oauth/request_token'
      method : 'POST'
      headers : 
        'Accept' : '*/*'
        'Content-Length' : '0'
        'Content-Type' : 'application/x-www-form-urlencoded'
        'Authorization' : @oauth_data
    options.agent = new https.Agent(options)
    req = https.request options, (res) =>
      res.on 'data', (chunk) ->
        console.log chunk+""
        dt = QUERY_STRING.parse(chunk+"")
        @access_token_secret = dt["oauth_token_secret"]
        @access_token = dt["oauth_token"]
        callback?@, "#{TwitterOAuth.URL.AUTHORIZE}?oauth_token=#{@access_token}"
      res.on 'error', (e) ->
        console.log e.message
    req.end()

  verify_oauth: (@access_token, @access_token_secret, @oauth_verifier, callback) ->
    true
	  
  tweet: (t) ->
    "" 

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
      oauth = new TwitterOAuth({consumer_key:TWITTER_CONSUMER_KEY,consumer_secret_key:TWITTER_CONSUMER_SECERT_KEY, access_token:"", access_token_secret:""})
      res.reply "I'm posting that tweet: #{tweet}"
       #tweet with oauth
    else
      robot.brain.set("#{user.id}:twitter:draft", tweet)
      oauth = new TwitterOAuth({consumer_key:TWITTER_CONSUMER_KEY, consumer_secret_key:TWITTER_CONSUMER_SECERT_KEY, callback: TWITTER_CALLBACK_URL})
      oauth.request_access_token (oa, verify_url) =>
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
    #/twitter/oauth?oauth_token=jpD7mAAAAAAAx3LuAAABWE9W-uY&oauth_verifier=bEU7Zs7lpXhTXsI9ajDG6FFARo3utYcH
    query = QUERY_STRING.parse(url.parse(req.url).query)
    access_token = query["oauth_token"]
    oauth_verifier = query["oauth_verifier"]
    user = robot.brain.get "twitter:#{access_token}"
    unless user?
      res.send 'ERROR'
      return
    access_token_secret = robot.brain.get("#{user.id}:twitter:access_token_secret_t")
    oauth = new TwitterOAuth({consumer_key:TWITTER_CONSUMER_KEY, consumer_secret_key:TWITTER_CONSUMER_SECERT_KEY, callback:TWITTER_CALLBACK_URL})
    oauth.verify_oauth access_token, access_token_secret, oauth, (oa)=>
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
    
    
