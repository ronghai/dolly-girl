https = require 'https' 
QUERY_STRING = require('querystring')
FS = require('fs')
CryptoJS = require('crypto-js')
crypto = require('crypto')
URL = require('url')
TwitterOAuth = require('./twitter-oauth')

TWITTER_CONSUMER_KEY = process.env.TWITTER_CONSUMER_KEY
TWITTER_CONSUMER_SECRET_KEY = process.env.TWITTER_CONSUMER_SECRET_KEY
TWITTER_CALLBACK_URL = process.env.TWITTER_CALLBACK_URL

module.exports = (robot) ->
  
  robot.share_link = (tweet) ->
    try 
      link = "https://twitter.com/#{tweet['user']['screen_name'].toLowerCase()}/status/#{tweet['id_str']}"
      return link
    catch error
      console.log(error)
      console.log(tweet)
      return JSON.stringify(tweet)

  robot.request_twitter_token = (user, draft, _callback)->
    robot.brain.set("#{user.id}:twitter:draft", draft)
    oauth = new TwitterOAuth({consumer_key:TWITTER_CONSUMER_KEY, consumer_secret_key:TWITTER_CONSUMER_SECRET_KEY, callback: TWITTER_CALLBACK_URL})
    oauth.request_token (oa, verify_url) =>
      robot.brain.set("#{user.id}:twitter:access_token_t", oa.access_token)
      robot.brain.set("#{user.id}:twitter:access_token_secret_t", oa.access_token_secret)
      robot.brain.set("twitter:#{oa.access_token}", user)
      _callback? verify_url

  robot.twitter_client = (user)->
    access_token = robot.brain.get "#{user.id}:twitter:access_token"
    access_token_secret = robot.brain.get "#{user.id}:twitter:access_token_secret"
    if access_token_secret?
      oauth = new TwitterOAuth({consumer_key:TWITTER_CONSUMER_KEY,consumer_secret_key:TWITTER_CONSUMER_SECRET_KEY, access_token:access_token, access_token_secret:access_token_secret})
      return oauth.client()
    else
      return null
  


  robot.handle_twitter_access_token = (query, _callback) ->
    access_token = query["oauth_token"]
    oauth_verifier = query["oauth_verifier"]
    user = robot.brain.get "twitter:#{access_token}"
    unless user?
      return "ERROR"
    access_token_secret = robot.brain.get("#{user.id}:twitter:access_token_secret_t")
    oauth = new TwitterOAuth({consumer_key:TWITTER_CONSUMER_KEY, consumer_secret_key:TWITTER_CONSUMER_SECRET_KEY, callback:TWITTER_CALLBACK_URL})
    oauth.request_access_token access_token, access_token_secret, oauth_verifier, (oa)=>
      robot.brain.set("#{user.id}:twitter:access_token", oa.access_token)
      robot.brain.set("#{user.id}:twitter:access_token_secret", oa.access_token_secret)
      robot.brain.remove "twitter:#{access_token}"
      robot.brain.remove "#{user.id}:twitter:access_token_t"
      robot.brain.remove "#{user.id}:twitter:access_token_secret_t" 
      draft = robot.brain.get "#{user.id}:twitter:draft"
      if draft?
        _callback(user, oauth,oauth.client(), draft)
    return "OK"

  robot.process_tweet = (client, tweet, _callback)->
    if client?
      client.post TwitterOAuth.STATUSES_UPDATE, {"status": tweet}, _callback

  robot.respond /twitter (.*)/i, (res) ->
    tweet = res.match[1]
    user = res.message.user
    client = robot.twitter_client(user)
    if client?
      robot.process_tweet client, tweet, (error, tweet, response)->
        res.reply robot.share_link(tweet)
    else
      robot.request_twitter_token user, tweet, (verify_url) ->
        room = robot.adapter.client.rtm.dataStore.getDMByName user.name
        res.reply "Please go to DM and click the link"
        robot.reply {room:room.id, user: user}, "Please click the following url to authorize your twitter account\n#{verify_url}"

  robot.respond /clear twitter account/i, (res) ->
    user = res.message.user
    robot.brain.remove "#{user.id}:twitter:access_token"
    robot.brain.remove "#{user.id}:twitter:access_token_secret"
    res.reply "Twitter's oAuth has been removed"
  
  robot.router.all '/twitter/oauth(/)?', (req, res) ->
    query = QUERY_STRING.parse(URL.parse(req.url).query)
    status = robot.handle_twitter_access_token query, (user, oauth, client, draft)->
      robot.process_tweet client, draft, (error, tweet, response)->
        room = robot.adapter.client.rtm.dataStore.getDMByName user.name
        robot.reply {room:room.id, user: user}, robot.share_link(tweet)
    res.send status



