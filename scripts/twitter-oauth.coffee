https = require 'https' 
QUERY_STRING = require('querystring')
FS = require('fs')
CryptoJS = require('crypto-js')
crypto = require('crypto')
URL = require('url')
Twitter = require('twitter');
class TwitterOAuth
  @STATUSES_UPDATE: "statuses/update"
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
      res.on 'data', (chunk) ->
        callback? chunk
      res.on 'error', (e) ->
        console.log e.message
    if post_data?
      req.write(post_data)
    req.end()

  authorization: (oauth_headers=[], sign) ->
    oauth_headers.push ["oauth_signature", sign]  if sign?
    oauth_headers = @sort_options oauth_headers
    oauth_data = @join_options oauth_headers, ", ", true
    oauth_data = "OAuth #{oauth_data}"
    @log(oauth_data)
    oauth_data

  request_token: (callback) ->
    oauth_headers = @oauth_params(["oauth_callback", @callback])
    sign = @signature(@extend_list([], oauth_headers), TwitterOAuth.URL.REQUEST, "POST", true)
    oauth_data = @authorization(oauth_headers, sign)
    @post TwitterOAuth.URL.BASE, TwitterOAuth.URL.REQUEST_PATH, oauth_data, null, (chunk) =>
      dt = QUERY_STRING.parse(chunk+"")
      #oauth_callback_confirmed=true
      if dt["oauth_token_secret"]?
        @access_token_secret = dt["oauth_token_secret"]
        @access_token = dt["oauth_token"]
        callback?@, "#{TwitterOAuth.URL.AUTHORIZE}?oauth_token=#{@access_token}"

  request_access_token: (@access_token, @access_token_secret, @oauth_verifier, callback) ->
    oauth_headers = @oauth_params()
    post_data = [["oauth_verifier", @oauth_verifier]]
    sign = @signature(@extend_list([], post_data, oauth_headers), TwitterOAuth.URL.ACCESS, "POST", false)
    oauth_data = @authorization(oauth_headers, sign)
    @post TwitterOAuth.URL.BASE, TwitterOAuth.URL.ACCESS, oauth_data, @join_options(post_data, '&', false), (chunk) =>
      dt = QUERY_STRING.parse(chunk+"")
      if dt["oauth_token_secret"]?
        @access_token_secret = dt["oauth_token_secret"]
        @access_token = dt["oauth_token"]
        callback?@

  tweet: (t, callback) ->
    oauth_headers = @oauth_params()
    post_data = [["status", t]]
    sign = @signature(@extend_list([],post_data, oauth_headers), TwitterOAuth.URL.POST, "POST", false)
    oauth_data = @authorization(oauth_headers, sign)
    @post TwitterOAuth.URL.BASE, TwitterOAuth.URL.POST+'?'+@join_options(post_data, '&', false), oauth_data,  null, (chunk) =>
      @log chunk+""
      msg = JSON.parse(chunk+"")
      link = "https://twitter.com/#{msg['user']['screen_name'].toLowerCase()}/status/#{msg['id_str']}"
      if link?
        callback?@, link

  client: ->
    return new Twitter({consumer_key: @consumer_key,  consumer_secret: @consumer_secret_key, access_token_key: @access_token, access_token_secret: @access_token_secret})
    
  share_link: (tweet) ->
    link = "https://twitter.com/#{tweet['user']['screen_name'].toLowerCase()}/status/#{tweet['id_str']}"
    return link


module.exports = TwitterOAuth
