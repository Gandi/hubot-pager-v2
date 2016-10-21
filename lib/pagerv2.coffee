# Description:
#   handles communication with PagerDuty API v2
#
# Dependencies:
#
# Configuration:
#  PAGERV2_API_KEY
#
# Author:
#   mose

Promise = require 'bluebird'
https = require 'https'
querystring = require 'querystring'

class Pagerv2

  constructor: (@robot, env) ->
    storageLoaded = =>
      @data = @robot.brain.data.pagerv2 ||= {
        users: { }
      }
      @robot.logger.debug 'Pagerduty V2 Data Loaded: ' + JSON.stringify(@data, null, 2)
    @robot.brain.on 'loaded', storageLoaded
    storageLoaded()

  request: (method, endpoint, query) =>
    return new Promise (res, err) ->
      if process.env.PAGERV2_API_KEY?
        auth = "Token token=#{process.env.PAGERV2_API_KEY}"
        body = querystring.stringify(query)
        options = 
          hostname: 'api.pagerduty.com'
          post: 443
          method: method
          path: endpoint
          headers:
            Authorization: auth
            Accept: 'application/vnd.pagerduty+json;version=2'
        req = https.request options, (response) ->
          data = ''
          response.on 'data', (chunk) ->
            data += chunk
          response.on 'end', ->
            res JSON.parse(data)
        req.end()
        req.on 'error', (error) =>
          err "#{error.code} #{error.message}"
      else
        err "PAGERV2_API_KEY is not set in your environment."

  getUser: (from, user) =>
    return new Promise (res, err) =>
      unless user.id?
        user.id = user.name
      if @data.users[user.id]?.pdid?
        res @data.users[user.id].pdid
      else
        @data.users[user.id] ?= {
          name: user.name,
          id: user.id
        }
        if user.pdid?
          @data.users[user.id].pdid = user.pdid
          res @data.users[user.id].pdid
        else
          email = @data.users[user.id].email_address or
                  @robot.brain.userForId(user.id)?.email_address or
                  user.email_address
          unless email
            err @_ask_for_email(from, user)
          else
            user = @data.users[user.id]
            query = { 'query': email }
            @request('GET', '/users', query)
            .then (body) ->
              if body.result['0']?
                user.pdid = body['users']['0']['id']
                res user.pdid
              else
                err "Sorry, I cannot find #{email} :("

  _ask_for_email: (from, user) ->
    if from.name is user.name
      "Sorry, I can't figure out your email address :( " +
      'Can you tell me with `.pd me as <email>`?'
    else
      if @robot.auth? and (@robot.auth.hasRole(from, ['pdadmin']) or
          @robot.auth.isAdmin(from))
        "Sorry, I can't figure #{user.name} email address. " +
        "Can you help me with `.pd #{user.name} as <email>`?"
      else
        "Sorry, I can't figure #{user.name} email address. " +
        'Can you ask them to `.pd me as <email>`?'

  getPermission: (user, group) =>
    return new Promise (res, err) =>
      isAuthorized = @robot.auth?.hasRole(user, [group, 'pdadmin']) or
                     @robot.auth?.isAdmin(user)
      if @robot.auth? and not isAuthorized
        err "You don't have permission to do that."
      else
        res()


module.exports = Pagerv2
