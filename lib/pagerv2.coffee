# Description:
#   handles communication with PagerDuty API v2
#
# Dependencies:
#
# Configuration:
#  PAGERV2_API_KEY
#  PAGERV2_SCHEDULE_ID  # the schedule used for oncall and overrides
#  PAGERV2_OVERRIDERS   # list of user_id that can be targets of overrides
#
# Author:
#   mose

https = require 'https'
moment = require 'moment'
Promise = require 'bluebird'
querystring = require 'querystring'

class Pagerv2

  constructor: (@robot) ->
    @robot.brain.data.pagerv2 ?= {
      users: { }
    }
    @logger = @robot.logger
    @logger.debug 'Pagerv2 Loaded'

  getPermission: (user, group) =>
    return new Promise (res, err) =>
      isAuthorized = @robot.auth?.hasRole(user, [group, 'pdadmin']) or
                     @robot.auth?.isAdmin(user)
      if @robot.auth? and not isAuthorized
        err "You don't have permission to do that."
      else
        res()

  request: (method, endpoint, query) ->
    return new Promise (res, err) ->
      if process.env.PAGERV2_API_KEY?
        auth = "Token token=#{process.env.PAGERV2_API_KEY}"
        body = querystring.stringify(query)
        options = {
          hostname: 'api.pagerduty.com'
          post: 443
          method: method
          path: endpoint
          headers: {
            Authorization: auth
            Accept: 'application/vnd.pagerduty+json;version=2'
          }
        }
        req = https.request options, (response) ->
          data = ''
          response.on 'data', (chunk) ->
            data += chunk
          response.on 'end', ->
            res JSON.parse(data)
        req.end()
        req.on 'error', (error) ->
          err "#{error.code} #{error.message}"
      else
        err 'PAGERV2_API_KEY is not set in your environment.'

  getUser: (from, user) =>
    return new Promise (res, err) =>
      @data = @robot.brain.data.pagerv2
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
          email = @data.users[user.id].email or
                  user.email_address
          unless email
            err @_ask_for_email(from, user)
          else
            user = @data.users[user.id]
            query = { 'query': email }
            @request('GET', '/users', query)
            .then (body) =>
              if body.users[0]?
                @robot.brain.data.pagerv2.users[user.id].pdid = body.users[0].id
                res body.users[0].id
              else
                err "Sorry, I cannot find #{email}"

  setUser: (user, email) =>
    return new Promise (res, err) =>
      @data = @robot.brain.data.pagerv2
      unless user.id?
        user.id = user.name
      @data.users[user.id] ?= {
        name: user.name,
        email: email,
        id: user.id
      }
      user = @data.users[user.id]
      query = { 'query': email }
      @request('GET', '/users', query)
      .then (body) =>
        if body.users[0]?
          @robot.brain.data.pagerv2.users[user.id].pdid = body.users[0].id
          res body.users[0].id
        else
          err "Sorry, I cannot find #{email}"

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

  setOverride: (from, who, duration) ->
    return new Promise (res, err) =>
      if duration > 1440
        err 'Sorry you cannot set an override of more than 1 day.'
      else
        duration = parseInt duration
        @data = @robot.brain.data.pagerv2
        schedule_id = process.env.PAGERV2_SCHEDULE_ID
        overriders = process.env.PAGERV2_SCHEDULE_ID.split(',')
        if not who? or who is 'me'
          who = from.name
        id = null
        @getUser(who)
        .bind(id)
        .then (id) ->
          getOncall()
        .then (oncall_name) ->
          query  = {
            'start': moment().format(),
            'end': moment().add(duration, 'minutes').format(),
            'user': {
              'id': id,
              'type': 'user_reference'
            }
          }
          # TODO - with user on call, res a relevant message

          res 'ok'
        .catch (error) ->
          err error

  getOncall: (schedule_id = process.env.PAGERV2_SCHEDULE_ID) ->
    return new Promise (res, err) =>
      query = {
        since: moment().format(),
        until: moment().add(1, 'minutes').format()
      }
      @request('GET', "/schedules/#{schedule_id}/users", query)
      .then (body) ->
        res body.users[0].name
      .catch (error) ->
        err error



module.exports = Pagerv2
