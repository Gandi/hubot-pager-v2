# Description:
#   handles communication with PagerDuty API v2
#
# Dependencies:
#
# Configuration:
#  PAGERV2_API_KEY
#  PAGERV2_SCHEDULE_ID       # the schedule used for oncall and overrides
#  PAGERV2_OVERRIDERS        # list of user_id that can be targets of overrides
#  PAGERV2_SERVICES          # list of services that are concerned by massive maintenance
#  PAGERV2_DEFAULT_RESOLVER  # name of the default user for resolution (ex. nagios)
#  PAGERV2_LOG_PATH          # dir where are saved error logs
#  PAGERV2_CUSTOM_ACTION     # listen for custom action (see README.md)
#
#
# Author:
#   mose
#   kolo

fs = require 'fs'
path = require 'path'
https = require 'https'
moment = require 'moment'
Promise = require 'bluebird'
querystring = require 'querystring'

class Pagerv2

  constructor: (@robot) ->
    @robot.brain.data.pagerv2 ?= {
      users: { },
      services: { },
      custom: { },
      custom_name: { }
    }
    @robot.brain.data.pagerv2.custom ?= { }
    @robot.brain.data.pagerv2.custom_name ?= { }
    @robot.brain.data.pagerv2.services ?= { }
    @robot.brain.data.pagerv2.schedules ?= { }
    @robot.brain.data.pagerv2.users ?= { }
    @pagerServices = [ ]
    if process.env.PAGERV2_SERVICES?
      for service in process.env.PAGERV2_SERVICES.split(',')
        @pagerServices.push(service)
    @logger = @robot.logger
    if process.env.PAGERV2_CUSTOM_ACTION_FILE?
      content = fs.readFileSync(process.env.PAGERV2_CUSTOM_ACTION_FILE)
      @robot.brain.data.pagerv2.custom = JSON.parse(content)
      @robot.brain.data.pagerv2.custom_name = { }
      for _, value of @robot.brain.data.pagerv2.custom
        if value.name?
          @robot.brain.data.pagerv2.custom_name[value.name] = value
    @logger.debug 'Pagerv2 Loaded'
    if process.env.PAGERV2_LOG_PATH?
      @errorlog = path.join process.env.PAGERV2_LOG_PATH, 'pagerv2-error.log'

  getPermission: (user, group) =>
    return new Promise (res, err) =>
      isAuthorized = @robot.auth?.hasRole(user, [group, 'pageradmin']) or
                     @robot.auth?.isAdmin(user)
      if process.env.PAGERV2_NEED_GROUP_AUTH? and
         process.env.PAGERV2_NEED_GROUP_AUTH isnt '0' and
         @robot.auth? and
         not(isAuthorized)
        err "You don't have permission to do that."
      else
        res()

  request: (method, endpoint, query, from = false, retry_count) ->
    return new Promise (res, err) =>
      if process.env.PAGERV2_API_KEY?
        auth = "Token token=#{process.env.PAGERV2_API_KEY}"
        body = JSON.stringify(query)
        if method is 'GET'
          qs = querystring.stringify(query)
          if qs isnt ''
            endpoint += "?#{qs}"
        options = {
          hostname: 'api.pagerduty.com'
          port: 443
          method: method
          path: endpoint
          headers: {
            Authorization: "#{auth}",
            Accept: 'application/vnd.pagerduty+json;version=2',
            'Content-Type': 'application/json'
          }
        }
        if from?
          options.headers.From = from
        req = https.request options, (response) =>
          data = []
          response.on 'data', (chunk) ->
            data.push chunk
          response.on 'end', =>
            if data.length > 0
              try
                json_data = JSON.parse(data.join(''))
                if json_data.error?
                  err "#{json_data.error.code} #{json_data.error.message}"
                else
                  res json_data
              catch e
                @robot.logger.error 'unable to parse answer'
                @robot.logger.error "query was : #{method} #{req.path}"
                if response.statusCode >= 429 and retry_count > 0 # 429 as "too many requests"
                  retry_count--
                  @request(method, endpoint, query, from, retry_count)
                  .then (rdata) ->
                    res rdata
                  .catch (rdata) ->
                    err rdata
                else
                  err 'Unable to read request output'
            else
              res { }
        req.on 'error', (error) ->
          err "#{error.code} #{error.message}"
        if method is 'PUT' or method is 'POST'
          req.write body
        req.end()
      else
        err 'PAGERV2_API_KEY is not set in your environment.'

  getUser: (from, user) =>
    return new Promise (res, err) =>
      unless user.id?
        user.id = user.name
      if @robot.brain.data.pagerv2.users[user.id]?.pagerid?
        res @robot.brain.data.pagerv2.users[user.id].pagerid
      else
        @robot.brain.data.pagerv2.users[user.id] ?= {
          name: user.name,
          id: user.id
        }
        email = @robot.brain.data.pagerv2.users[user.id].email or user.email_address
        unless email
          err @_ask_for_email(from, user)
        else
          user = @robot.brain.data.pagerv2.users[user.id]
          query = { 'query': email }
          @request('GET', '/users', query)
          .then (body) =>
            if body.users[0]?
              @robot.brain.data.pagerv2.users[user.id].pagerid = body.users[0].id
              res body.users[0].id
            else
              err "Sorry, I cannot find #{email}"

  getUserEmail: (from, user) ->
    return new Promise (res, err) =>
      unless user.id?
        user.id = user.name
      email = @robot.brain.data.pagerv2.users[user.id]?.email or user.email_address
      if email?
        res email
      else
        err @_ask_for_email(from, user)

  setUser: (user, email) =>
    return new Promise (res, err) =>
      unless user.id?
        user.id = user.name
      @robot.brain.data.pagerv2.users[user.id] ?= {
        name: user.name,
        email: email,
        id: user.id
      }
      user = @robot.brain.data.pagerv2.users[user.id]
      query = { 'query': email }
      @request('GET', '/users', query)
      .then (body) =>
        if body.users[0]?
          @robot.brain.data.pagerv2.users[user.id].pagerid = body.users[0].id
          @robot.brain.data.pagerv2.users[user.id].email = email
          res body.users[0].id
        else
          err "Sorry, I cannot find #{email}"
      .catch (e) ->
        err e

  _ask_for_email: (from, user) ->
    if from.name is user.name
      "Sorry, I can't figure out your email address :( " +
      'Can you tell me with `.pager me as <email>`?'
    else
      if @robot.auth? and (@robot.auth.hasRole(from, ['pageradmin']) or
         @robot.auth.isAdmin(from))
        "Sorry, I can't figure #{user.name} email address. " +
        "Can you help me with `.pager #{user.name} as <email>`?"
      else
        "Sorry, I can't figure #{user.name} email address. " +
        'Can you ask them to `.pager me as <email>`?'
  
  getScheduleIdByName: (name) ->
    new Promise (res, err) =>
      if @robot.brain.data.pagerv2.schedules[name]?
        res @robot.brain.data.pagerv2.schedules[name]
      else
        @request('GET', '/schedules')
        .then (body) =>
          for schedule in body.schedules
            @robot.brain.data.pagerv2.schedules[schedule.name] = schedule.id
            if schedule.name is name
              res schedule.id
              return
          throw new Error("no matching schedule found")
        .catch (e) ->
          err "#{e}"
  
  getSchedule: (schedule_id = process.env.PAGERV2_SCHEDULE_ID) ->
    @request('GET', "/schedules/#{schedule_id}")
    .then (body) ->
      body.schedule

  getOverride: (schedule_id = process.env.PAGERV2_SCHEDULE_ID) ->
    query = {
      since: moment().format(),
      until: moment().add(1, 'minutes').format(),
      editable: 'true',
      overflow: 'true'
    }
    @request('GET', "/schedules/#{schedule_id}/overrides", query)
    .then (body) ->
      body.overrides
      
  getFirstOncall: (fromtime = null, schedule_id = process.env.PAGERV2_SCHEDULE_ID) ->
    @getOncall(fromtime,schedule_id)
    .then (data) ->
      return data[0]

  printOncall: (oncall,schedule=false) ->
    nowDate = moment().utc()
    endDate = moment(oncall.end).utc()
    if nowDate.isSame(endDate, 'day')
      endDate = endDate.format('HH:mm')
    else
      endDate = endDate.format('dddd HH:mm')
    if schedule
      in_schedule = " in #{oncall.schedule.summary}."
    else
      in_schedule = '.'
    return "#{oncall.user.summary} is on call until #{endDate} (utc)#{in_schedule}"

  getOncall: (fromtime = null, schedule_id = process.env.PAGERV2_SCHEDULE_ID) ->
    query = {
      time_zone: 'UTC',
      'schedule_ids[]': schedule_id,
      earliest: 'true'
    }
    if fromtime?
      query['since'] = moment(fromtime).utc().add(1, 'minutes').format()
      query['until'] = moment(fromtime).utc().add(2, 'minutes').format()
    @request('GET', '/oncalls', query)
    .then (body) ->
      body.oncalls

  setOverride: (from,
  who,
  duration = null,
  start = null,
  schedule_id = process.env.PAGERV2_SCHEDULE_ID) ->
    return new Promise (res, err) =>
      if duration? and duration > 1440
        err 'Sorry you cannot set an override of more than 1 day.'
      else
        if not who? or not who.name? or who.name is 'me'
          who = { name: from.name }
        if who?
          @getUser(from, who)
          .bind({ id: null })
          .then (id) =>
            @id = id
            @getFirstOncall(start)
          .then (data) =>
            query = { override: { } }
            if @id is data.user.id
              err "Sorry, you can't override yourself"
            else
              if start?
                momentStart = moment(start).utc()
                data.start = start
              else
                momentStart = moment().utc()
              query.override.start = momentStart.format()
              if not start and duration?
                duration = parseInt duration
                query.override.end = momentStart.add(duration, 'minutes').format()
              else
                query.override.end = moment(data.end).utc().format()
              query.override.user = {
                'id': "#{@id}",
                'type': 'user_reference'
              }
              @request('POST', "/schedules/#{schedule_id}/overrides", query)
              .then (body) ->
                body.override.over = {
                  name: who.name or who,
                  from: data.user.summary,
                  start: data.start,
                  end: data.end
                }
                res body.override
          .catch (error) ->
            err error

  dropOverride: (from, who) ->
    return new Promise (res, err) =>
      schedule_id = process.env.PAGERV2_SCHEDULE_ID
      if not who? or not who.name? or who.name is 'me'
        who = { name: from.name }
      if who?
        @getUser(from, who)
        .bind({ id: null })
        .then (id) =>
          @id = id
          @getOverride()
        .then (data) =>
          if data
            todo = null
            for over in data
              if over.user.id is @id
                todo = over.id
            if todo?
              @request('DELETE', "/schedules/#{schedule_id}/overrides/#{todo}")
              .then (data) ->
                res data
              .catch (e) ->
                err e
            else
              res null
          else
            res null

  getIncident: (incident) ->
    @request('GET', "/incidents/#{incident}")

  listIncidents: (
    incidents = '',
    statuses = 'triggered,acknowledged',
    date_since = null,
    date_until = null,
    limit = 100
  ) ->
    if incidents isnt ''
      new Promise (res, err) ->
        res {
          incidents: incidents.split(/[, ]+/).map (inc) ->
            { id: inc }
          }
    else
      query = {
        time_zone: 'UTC',
        'urgencies[]': 'high',
        sort_by: 'created_at'
      }
      if date_since?
        unless date_until?
          date_until = moment().utc()
        query['since'] = moment(date_since).utc().format()
        query['until'] = moment(date_until).utc().format()
      else
        query['date_range'] = 'all'
      if statuses?
        query['statuses[]'] = statuses.split /,/
      query['limit'] = limit
      query['total'] = 'true'
      @request('GET', '/incidents', query)
      .then (data) =>
        if data.total > 100
          pages = Math.floor(data.total / 100)
          Promise.each [1..pages], (offset) =>
            query['offset'] =  offset * 100
            @request('GET', '/incidents', query)
            .then (page) ->
              data.incidents = data.incidents.concat(page.incidents)
          .then ->
            data
        else
          data

  completeIncidentWithNotes: (incident) =>
    @listNotes(incident.id)
    .then (payload) ->
      incident.notes = payload.notes
      return incident

  listIncidentsWithNotes: (
    incidents = '',
    statuses = 'triggered,acknowledged',
    date_since = null,
    date_until = null,
    limit = 100
  ) ->
    @listIncidents(incidents, statuses, date_since, date_until, limit)
    .then (data) =>
      alldata = Promise.map(data.incidents, @completeIncidentWithNotes, { concurrency: 2 })
      Promise.all(alldata)
      .then (incidents) ->
        { incidents: incidents }

  upagerateIncidents: (user, incidents = '', which = 'triggered', status = 'acknowledged') ->
    @getUserEmail(user, user)
    .bind({ from: null })
    .then (email) =>
      @from = email
      @listIncidents incidents, which
    .then (data) =>
      if data.incidents.length > 0
        payload = {
          incidents: []
        }
        for inc in data.incidents
          payload.incidents.push {
            id: inc.id,
            type: 'incident_reference',
            status: status
          }
        @request('PUT', '/incidents', payload, @from)
      else
        throw { message: "There is no #{which} incidents at the moment." }

  assignIncidents: (user, who, incidents = '') ->
    @getUserEmail(user, user)
    .bind({ from: null })
    .bind({ assignees: null })
    .then (email) =>
      @from = email
      assigneesDone = Promise.map who.split(/, ?/), (assignee) =>
        @getUser(user, { name: assignee })
      Promise.all assigneesDone
    .then (assignees) =>
      @assignees = assignees
      @listIncidents incidents
    .then (data) =>
      if data.incidents.length > 0
        payload = {
          incidents: []
        }
        for inc in data.incidents
          assignments = []
          for a in @assignees
            assignments.push {
              assignee: {
                id: a,
                type: 'user_reference'
              }
            }
          payload.incidents.push {
            id: inc.id,
            type: 'incident_reference',
            assignments: assignments
          }
        @request('PUT', '/incidents', payload, @from)
      else
        throw { message: 'There is no incidents at the moment.' }

  snoozeIncidents: (user, incidents = '', duration = 120) ->
    @getUserEmail(user, user)
    .bind({ from: null })
    .then (email) =>
      @from = email
      @listIncidents incidents
    .then (data) =>
      if data.incidents.length > 0
        incidentsDone = Promise.map data.incidents, (inc) =>
          payload = {
            duration: +duration * 60
          }
          @request('POST', "/incidents/#{inc.id}/snooze", payload, @from)
        Promise.all incidentsDone
      else
        throw { message: 'There is no open incidents at the moment.' }

  addNote: (user, incident, note) ->
    @getUserEmail(user, user)
    .then (email) =>
      payload = {
        note: {
          content: note
        }
      }
      @request('POST', "/incidents/#{incident}/notes", payload, email)

  listNotes: (incident) ->
    @request('GET', "/incidents/#{incident}/notes", undefined, undefined, 1)

  listMaintenances: ->
    query = {
      filter: 'ongoing'
    }
    @request('GET', '/maintenance_windows', query)

  addMaintenance: (user, duration = 60, description, services = []) ->
    @getUserEmail(user, user)
    .bind(@email)
    .then (email) =>
      @email = email
      if services.length is 0
        services = @pagerServices
      service_ids = Promise.map services, (service) =>
        @serviceId(service)
      Promise.all(service_ids)
    .then (service_ids) =>
      payload = {
        maintenance_window: {
          type: 'maintenance_window',
          start_time: moment().format(),
          end_time: moment().add(duration, 'minutes').format(),
          description: description or 'Maintenance in progress.',
          services: [ ]
        }
      }
      for service in service_ids
        payload.maintenance_window.services.push {
          id: service,
          type: 'service_reference'
        }
      @request('POST', '/maintenance_windows', payload, @email)

  endMaintenance: (user, id) ->
    @request('DELETE', "/maintenance_windows/#{id}", { })

  coloring: {
    irc: (text, color) ->
      colors = require('irc-colors')
      if colors[color]
        colors[color](text)
      else
        text

    slack: (text, color) ->
      "*#{text}*"

    generic: (text, color) ->
      text
  }

  getService: (name) ->
    payload = {
      query: name
    }
    @request('GET', '/services', payload)

  serviceId: (name) ->
    new Promise (res, err) =>
      if @robot.brain.data.pagerv2.services[name]?
        res @robot.brain.data.pagerv2.services[name]
      else
        @getService(name)
        .then (payload) =>
          @robot.brain.data.pagerv2.services[name] = payload.services[0].id
          res @robot.brain.data.pagerv2.services[name]
  listExtensions: (name) ->
    if name?
      query = {
        query: name
      }
    else
      query = { }
    @request('GET', '/extensions', query)

  parseWebhook: (adapter, messages) =>
    return new Promise (res, err) =>
      res messages.map (message) =>
        try
          incident = if message.type? then message.data.incident else message.incident
          type = if message.type? then message.type else message.event
          level = type.substring(type.indexOf('.') + 1)
          if level is 'custom'
            return @launchActionById(message.webhook.id)
          else
            return @printIncident(incident, type, adapter)
        catch e
          @robot.logger.error 'unable to parse message'
          @robot.logger.error message
          @robot.logger.error e
          return 'Message parsing failed'

  launchActionById: (action_id) =>
    if @robot.brain.data.pagerv2.custom?[action_id]?
      custom_action = @robot.brain.data.pagerv2.custom[action_id]
      return @robot.emit(custom_action.action, custom_action.args)
    else
      return "Unknown action for id #{action_id}"

  launchActionByName: (name) =>
    if @robot.brain.data.pagerv2.custom_name?[name]?
      custom_action = @robot.brain.data.pagerv2.custom_name[name]
      @robot.emit(custom_action.action, custom_action.args)
      "Action \"#{name}\" sent"
    else
      "Unknown action for name #{name}"

  listActions: (name) =>
    actions = new Array()
    if @robot.brain.data.pagerv2.custom_name?[name]?
      custom_action = @robot.brain.data.pagerv2.custom_name[name]
      details = if custom_action.summary? then custom_action.summary else custom_action.action
      actions.push("[#{name}] : #{details}")
    else
      if @robot.brain.data.pagerv2.custom_name?
        for key, value of @robot.brain.data.pagerv2.custom_name
          custom_action = @robot.brain.data.pagerv2.custom_name[key]
          details = if custom_action.summary? then custom_action.summary else custom_action.action
          actions.push("[#{key}] : #{details}")

    if actions.length is 0
      return ['No named action available']
    else
      return actions

  printIncident: (incident, type, adapter) =>
    level = type.split('.')[type.split('.').length - 1]
    service = 'unknown'
    if incident.service.name?
      service = incident.service.name
    else if incident.service.summary?
      service = incident.service.summary
    origin = @colorer(adapter,
      level,
      "[#{service}]"
    )
    if incident.trigger_summary_data?
      if incident.trigger_summary_data.subject?
        description = incident.trigger_summary_data.subject.
                      replace(' (CRITICAL)', '')
      else if incident.trigger_summary_data.description?
        description = incident.trigger_summary_data.description
    if not description? and incident.summary?
      description = incident.summary
    if not description?
      description = '(no subject)'
    who = @get_assignee(incident, type)
    "#{origin} #{incident.id} - #{description} - #{level} (#{who})"

  get_assignee: (incident, type) =>
    if type? and type is 'incident.resolve' and incident.resolved_by_user?
      who = incident.resolved_by_user.name
    else if incident.assigned_to_user?
      who = incident.assigned_to_user.name
    else if incident.assignments?
      who = []
      for assignment in incident.assignments
        who.push(assignment.assignee.summary)
        who = who.join(',')
    else
      who = process.env.PAGERV2_DEFAULT_RESOLVER or 'nagios'
      @robot.logger.warning("fallback parsing triggered for incident #{incident.id}")
      @robot.logger.debug(incident)
    return who

  colorer: (adapter, level, text) ->
    colors = {
      trigger: 'red',
      triggered: 'red',
      unacknowledge: 'red',
      unacknowledged: 'red',
      acknowledge: 'yellow',
      acknowledged: 'yellow',
      resolve: 'green',
      resolved: 'green',
      assign: 'blue',
      escalate: 'blue'
    }
    if @coloring[adapter]?
      @coloring[adapter](text, colors[level])
    else
      @coloring.generic(text, colors[level])
 
  logError: (message, payload) ->
    if @errorlog?
      fs.appendFileSync @errorlog, '\n---------------------\n'
      fs.appendFileSync @errorlog, "#{moment().utc().format()} - #{message}\n\n"
      fs.appendFileSync @errorlog, JSON.stringify(payload, null, 2), 'utf-8'



module.exports = Pagerv2
