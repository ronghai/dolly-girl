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
  robot.respond /twitter (.*)/i, (res) ->
    tweet = res.match[1]
    user = res.message.user
    access_token = robot.brain.get "#{user.id}:twitter:access_token"
    access_token_secret = robot.brain.get "#{user.id}:twitter:access_token_secret" 
    if access_token?
      oauth = new TwitterOAuth({consumer_key:TWITTER_CONSUMER_KEY,consumer_secret_key:TWITTER_CONSUMER_SECRET_KEY, access_token:access_token, access_token_secret:access_token_secret})
      res.reply "I'm posting that tweet: #{tweet}"
      room = robot.adapter.client.rtm.dataStore.getDMByName user.name
      oauth.tweet tweet, (oa, _url) ->
        res.reply _url
    else
      robot.brain.set("#{user.id}:twitter:draft", tweet)
      oauth = new TwitterOAuth({consumer_key:TWITTER_CONSUMER_KEY, consumer_secret_key:TWITTER_CONSUMER_SECRET_KEY, callback: TWITTER_CALLBACK_URL})
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
    query = QUERY_STRING.parse(URL.parse(req.url).query)
    access_token = query["oauth_token"]
    oauth_verifier = query["oauth_verifier"]
    user = robot.brain.get "twitter:#{access_token}"
    unless user?
      res.send 'ERROR'
      return
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
        room = robot.adapter.client.rtm.dataStore.getDMByName user.name
        robot.reply {room:room.id, user: user}, "I'm posting that tweet: #{draft}"
        oa.tweet draft, (_oa, _url)->
           robot.reply {room:room.id, user: user}, _url
    res.send 'OK'
    
