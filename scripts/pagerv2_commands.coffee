# Description:
#   enable communication with Pagerduty using API v2
#
# Dependencies:
#
# Configuration:
#
# Commands:
#   hubot pager version             - give the version of hubot-pager-v2 loaded
#
#   hubot pager me                  - check if the caller is known by pagerduty plugin
#   hubot pager me as <email>       - declare what email should be use to find caller pagerduty id
#   hubot pager <user> as <email>   - declare what email should be use to find <user> pagerduty id
#   hubot pager who is <user>       - check if the caller is known by pagerduty plugin
#
#   hubot pager noc <duration>      - creates an override for <duration> minutes with the noc account
#   hubot pager noc now             - creates a noc override until the end of current oncall
#   hubot pager not noc             - cancels a noc override if any
#
#   hubot pager incident <#>        - gives more information about incident number <number>
#   hubot pager sup|inc|incidents   - lists currently unresolved incidents
#
#   hubot pager ack [all]           - acknowledges any unack incidents
#   hubot pager ack <#,#,#>         - acknowledges incident <number>
#
#   hubot pager res|resolve [all]   - resolves any un-resolved incidents
#   hubot pager res|resolve <#,#,#> - resolves incident <number>
#
#   hubot pager snooze [all] [for] [<duration>] [min]   - snoozes any open incidents for [<duration>] (default 120m)
#   hubot pager snooze <#,#,#> [for] [<duration>] [min] - snoozes incident <number>
#
#   hubot pager assign [all] to me       - assigns all open incidents to caller
#   hubot pager assign [all] to <user>   - assigns all open incidents to user
#   hubot pager assign <#,#,#> to me     - assigns incidents <#,#,#> to caller
#   hubot pager assign <#,#,#> to <user> - assigns incidents <#,#,#> to user
#
#   hubot pager note <#,#,#> <note> - create a note for incidents <#,#,#>
#   hubot pager notes <#>           - read notes for incident <#>
#
#   hubot pager [who is] oncall        - tells who is currently on call
#   hubot pager [who is] next [oncall] - tells who is next on call
#   hubot pager oncall <message>       - cc oncall and send <message> to alerting channel
#
#   hubot pager sched[ule] [schedule_name] - returns who is on call
#   hubot pager sched[ules] - list available schedules
#
#   hubot pager maintenances           - lists currently active maintenances
#   hubot pager stfu|down [for] <duration> [because <reason>] - creates a maintenance
#   hubot pager stfu|down <service,service,service> for <duration> [because <reason>] - creates a maintenance per service
#   hubot pager end <maintenance> - ends <maintenance>
#
#   hubot pager extensions [name] - list extensions matching name (or list all)
#
#   hubot pager run <action name>   - run a custom action
#   hubot pager actions             - list available action
#
#   hubot pager me <duration>       - creates an override for <duration> minutes
#   hubot pager me next             - creates an override for the next scheduled
#   hubot pager me now              - creates an override until the end of current oncall
#   hubot pager not me              - cancels an override if any
#
#
# Author:
#   mose
#   kolo

Pagerv2 = require '../lib/pagerv2'
moment = require 'moment'
path = require 'path'

module.exports = (robot) ->

  robot.brain.data.pagerv2 ?= { users: { } }
  robot.pagerv2 ?= new Pagerv2 robot, process.env
  pagerv2 = robot.pagerv2
  # console.log robot.pagerv2.data

#   hubot pager version - give the version of hubot-pager-v2 loaded
  robot.respond /pager version\s*$/, 'pager_version', (res) ->
    pkg = require path.join __dirname, '..', 'package.json'
    res.send "hubot-pager-v2 is version #{pkg.version}"
    res.finish()

#   hubot pager me - check if the caller is known by pagerduty plugin
  robot.respond /pager me\s*$/, (res) ->
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.getUser(res.envelope.user, res.envelope.user)
    .then (data) ->
      res.send "Oh I know you, you are #{data}."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager me as <email> - declare what email should be use to find user pagerduty id
  robot.respond /pager me as ([^\s@]+@[^\s]+)\s*$/, 'pager_me_as', (res) ->
    [ _, email ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.setUser(res.envelope.user, email)
    .then (data) ->
      res.send "Ok now I know you are #{data}."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager <user> as <email> - declare what email should be use to find <user> pagerduty id
  robot.respond /pager ([^\s]+) as ([^\s@]+@[^\s]+)\s*$/, 'pager_user_as', (res) ->
    who = null
    [ _, who, email ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageradmin')
    .then ->
      pagerv2.setUser( { name: who }, email)
    .bind(who)
    .then (data) ->
      res.send "Ok now I know #{who} is #{data}."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager [who is] next [oncall] - tells who is next on call
  robot.respond (
    /(?:pager )?(?:who(?: is|'s) )?(next on ?call|on ?call next)\s*$/
  ), 'pager_next_oncall', (res) ->
    pagerv2.getFirstOncall()
    .then (data) ->
      fromtime = moment(data.end).utc().add(1, 'minute').format()
      pagerv2.getFirstOncall(fromtime)
    .then (data) ->
      nowDate = moment().utc()
      startDate = moment(data.start).utc()
      if nowDate.isSame(startDate, 'day')
        startDate = 'at ' + startDate.format('HH:mm')
      else
        startDate = 'on ' + startDate.format('dddd HH:mm')
      endDate = moment(data.end).utc()
      if nowDate.isSame(endDate, 'day')
        endDate = endDate.format('HH:mm')
      else
        endDate = endDate.format('dddd HH:mm')
      res.send "#{data.user.summary} will be next on call #{startDate} until #{endDate} (utc)."
    .catch (e) ->
      res.send e
    res.finish()


#   hubot pager oncall <message> - cc oncall and send <message> to alerting channel
  robot.respond /(?:pager )?on ?call\s(.+)/, 'pager_msg_oncall', (res) ->
    [ _, msg ] = res.match
    alertchan = process.env.PAGERV2_ANNOUNCE_ROOM
    pagerv2.getFirstOncall()
    .then (data) ->
      if not data?
        res.send 'Nobody is oncall'
        return
      if res.envelope.room?
        res.send "cc #{data.user.summary}"
      else
        res.send "Ok, I'll notify #{data.user.summary}."
      if alertchan isnt res.envelope.room
        origin = if res.envelope.room then " on #{res.envelope.room}" else ''
        robot.messageRoom alertchan,
            "#{data.user.summary}: #{msg} (from #{res.envelope.user.name}#{origin})"
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager [who is] oncall - returns who is on call
  robot.respond /(?:pager )?(?:who(?: is|'s) )?on ?call\s*$/, 'pager_oncall', (res) ->
    pagerv2.getFirstOncall()
    .then (data) ->
      res.send pagerv2.printOncall(data)
    .catch (e) ->
      res.send e
    res.finish()

  robot.on 'schedule', (params) ->
    if params.room? and params.schedule_id?
      pagerv2.getOncall(null, params.schedule_id)
      .then (data) ->
        if data? and data.length? and data.length > 0
          if params.message? and params.who?
            if params.where is params.room
              robot.messageRoom(params.room, "cc #{data[0].user.summary}")
            else
              if not params.where?
                params.where = '(private)'
              robot.messageRoom(
                params.room,
                "#{data[0].user.summary}: #{params.message} from #{params.who} in #{params.where}")
          else
            if params.where?
              target = params.where
            else
              target = params.who
            robot.messageRoom(target, pagerv2.printOncall(data[0], true))
        else
          pagerv2.getSchedule(params.schedule_id)
          .then (data) ->
            message = 'Nobody is oncall at the moment on the schedule' +
                    " #{data.name} : #{data.description}"
            if params.where?
              target = params.where
            else
              target = params.who
            robot.messageRoom(target, message)
      .catch (e) ->
        robot.messageRoom params.room, "Unable to get oncall : #{e}"
       
#   hubot pager sched[ules] - list available schedules
  robot.respond /pager sched(?:ules)?\s*$/, 'pager_sched', (res) ->
    [_, schedule_name] = res.match
    pagerv2.getSchedules()
    .then (data) ->
      for schedule in data.schedules
        res.send "[#{schedule.id}] #{schedule.name} : #{schedule.summary}"
    .catch (e) ->
      res.send e
    res.finish()



#   hubot pager sched[ule] [schedule_name] - returns who is on call
  robot.respond /pager sched(?:ule)? (.*)$/, 'pager_sched', (res) ->
    [_, schedule_name] = res.match
    pagerv2.getScheduleIdByName(schedule_name)
    .then (schedule_id) =>
      params = { }
      params.schedule_id = schedule_id
      params.room = res.envelope.room
      if not params.room?
        params.room = res.envelope.user
      @robot.emit 'schedule', params
    .catch (e) ->
      res.send e
    res.finish()


#   hubot pager who is <user> - check if the caller is known by pagerduty plugin
  robot.respond /pager who(?: is|'s)? ([^\s]+)$/, (res) ->
    [_, who] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageradmin')
    .then ->
      pagerv2.getUser( res.envelope.user, { name: who })
    .then (data) ->
      res.send "Oh I know #{who}, #{who} is #{data}."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager incident <#> - gives more information about incident number <number>
  robot.respond /pager (?:inc |incident )#?(\d+|[A-Z0-9]+)\s*$/, 'pager_incident', (res) ->
    [ _, incident ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.getIncident(incident)
    .then (data) ->
      pagerv2.getIncidentWithAlerts(data.incident)
      .then (incWithAlerts) ->
        res.send pagerv2.printIncident(incWithAlerts, incWithAlerts.status, robot.adapterName)
      #"#{origin}#{data.incident.id} #{data.incident.summary} - #{data.incident.status}" +
      #         "#{assigned}"
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager sup|inc|incidents - lists currently unresolved incidents
  robot.respond (
    /(?:pager )?(?:supo?|inc(?:idents))\s*(\d+)?(?: (\d+))?(?: (\d+))?\s*$/
  ), 'pager_incidents', (res) ->
    [ _, from, duration, limit ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      status = null
      if from?
        from = moment().utc().subtract(from, 'hours')
        if duration?
          to = moment(from).add(duration, 'hours')
        status = 'triggered,acknowledged,resolved'
      pagerv2.listIncidents('', status, from, to, limit)
    .then (data) ->
      if data.incidents.length > 0
        for inc in data.incidents
          pagerv2.getIncidentWithAlerts(inc)
          .then (incWithAlerts) ->
            res.send pagerv2.printIncident(incWithAlerts, incWithAlerts.status, robot.adapterName)
          #"#{origin}#{inc.id} #{inc.summary} - #{inc.status}#{assigned}"
      else
        res.send 'There are no open incidents for now.'
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager ack [all]         - acknowledges any unack incidents
  robot.respond /(?:pager )?(?:a|A)ck(?: all)?\s*$/, 'pager_ack_all', (res) ->
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.upagerateIncidents(res.envelope.user)
    .then (data) ->
      plural = ''
      if data.incidents.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')} acknowledged."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pager ack <#,#,#>           - acknowledges incident <number>
  robot.respond /pager ack #?(.+)\s*$/, 'pager_ack_one', (res) ->
    [ _, incidents ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.upagerateIncidents(res.envelope.user, incidents)
    .then (data) ->
      plural = ''
      if data.incidents.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')} acknowledged."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pager res|resolve [all]      - resolves any unresolved incidents
  robot.respond /pager res(?:olve)?(?: all)?\s*$/, 'pager_res_all', (res) ->
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.upagerateIncidents(res.envelope.user, '', 'acknowledged', 'resolved')
    .then (data) ->
      plural = ''
      if data.incidents.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')} resolved."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pager res|resolve <#,#,#>   - resolves incident <number>
  robot.respond /pager res(?:olve)? #?(.+)\s*$/, 'pager_res_one', (res) ->
    [ _, incidents ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.upagerateIncidents(res.envelope.user, incidents, 'acknowledged', 'resolved')
    .then (data) ->
      plural = ''
      if data.incidents.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')} resolved."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pager assign [all] to me       - assigns all open incidents to caller
#   hubot pager assign [all] to <user>   - assigns all open incidents to user
  robot.respond /pager (?:re)?assign(?: all) to (me|[^ ]+)\s*$/, 'pager_assign_all', (res) ->
    [ _, who ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      if who is 'me'
        who = res.envelope.user.name
      pagerv2.assignIncidents(res.envelope.user, who)
    .then (data) ->
      plural = ''
      if data.incidents.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')} " +
               "assigned to #{who}."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pager assign <#,#,#> to me     - assigns incidents <#,#,#> to caller
#   hubot pager assign <#,#,#> to <user> - assigns incidents <#,#,#> to user
  robot.respond /pager assign #?(.+) to (me|[^ ]+)\s*$/, 'pager_assign_one', (res) ->
    [ _, incidents, who ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      if who is 'me'
        who = res.envelope.user.name
      pagerv2.assignIncidents(res.envelope.user, who, incidents)
    .then (data) ->
      plural = ''
      if data.incidents.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')} " +
               "assigned to #{who}."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pager steal <#,#,#> - assign and ack <#,#,#> to caller
#   hubot pager steal all - assign and ack all to caller
  robot.respond /pager steal #?(.+)/, 'pager_steal', (res) ->
    [ _, incidents ] = res.match
    if incidents is 'all'
      incidents = ''
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      who = res.envelope.user.name
      pagerv2.assignIncidents(res.envelope.user, who, incidents)
      .then (data) ->
        who = res.envelope.user
        pagerv2.upagerateIncidents(who, data.incidents.map((e) -> e.id).join(','),
        'triggered', 'acknowledged')
      .then (data) ->
        plural = ''
        if data.incidents.length > 1
          plural = 's'
        res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')}"+
        " acknowledged and assigned to #{res.envelope.user.name}."
      .catch (e) ->
        res.send e.message or e
    res.finish()

#   hubot pager snooze [all] [for] [<duration>] [min]
#   - snoozes all incidents for [<duration>] (default 120m)
  robot.respond (
    /pager snooze(?: all)?(?: (?:for )(\d+)(?: min(?:utes)?)?)?\s*$/
  ), 'pager_snooze_all', (res) ->
    [ _, duration ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.snoozeIncidents(res.envelope.user, '', duration)
    .then (data) ->
      plural = ''
      if data.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.map( (e) -> e.incident.id).join(', ')} snoozed."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pager snooze <#,#,#> [for] [<duration>] [min]
#   - snoozes incident <number> for [<duration>] (default 120m)
  robot.respond (
    /pager snooze #?([^ ]+)(?: (?:for )?(\d+)(?: min(?:utes)?)?)?\s*$/
  ), 'pager_snooze_one', (res) ->
    [ _, incidents, duration ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.snoozeIncidents(res.envelope.user, incidents, duration)
    .then (data) ->
      plural = ''
      if data.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.map( (e) -> e.incident.id).join(', ')} snoozed."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pager note <#,#,#> <note> - create a note for incidents <#,#,#>
  robot.respond /pager note (?:\s*)?#?([^\s]+) (.*)$/, 'pager_note', (res) ->
    [ _, incident, note ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.addNote(res.envelope.user, incident, note)
    .then (data) ->
      res.send "Note added to #{incident}: #{note}."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager notes <#>           - read notes for incident <#>
  robot.respond /pager notes #?([^\s]+)\s*$/, 'pager_notes', (res) ->
    [ _, incident ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.listNotes(incident)
    .then (data) ->
      if data.notes.length > 0
        for note in data.notes
          res.send "#{incident} - #{note.content}"
      else
        res.send "#{incident} has no notes."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager maintenances           - lists currently active maintenances
  robot.respond /pager maintenances?\s*$/, 'pager_maintenances', (res) ->
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.listMaintenances()
    .then (data) ->
      if data.maintenance_windows.length > 0
        for maintenance in data.maintenance_windows
          end = moment(maintenance.end_time).utc().format('HH:mm')
          services = ''
          for service in maintenance.services
            services += service.summary + ', '
          services = services.substring(0, services.length - 2)
          res.send "#{maintenance.id} - #{maintenance.summary} (until #{end} UTC) on #{services}"
      else
        res.send 'There is no ongoing maintenance at the moment.'
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager extensions [name] - list extensions matching name (or list all)
  robot.respond /pager extensions? ?(.*)?$/, 'pager_extensions', (res) ->
    [_, name] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.listExtensions(name)
      .then (data) ->
        for ext in data.extensions
          res.send "[#{ext.id}] #{ext.name}: #{ext.summary} - #{ext.extension_schema.summary}"
        if data.extensions.length < 1
          res.send 'No extension found'
    .catch (e) ->
      res.send e
    res.finish()

#   hubot actions - list custom action
  robot.respond /pager actions ?(.*)?$/, 'pager_actions', (res) ->
    [_, name] = res.match
    for line in pagerv2.listActions(name)
      res.send line
    res.finish()

#   hubot run action name - run a specific action
  robot.respond /pager run (.*)$/, 'pager_run', (res) ->
    [_, name] = res.match
    res.send pagerv2.launchActionByName(name)
    res.finish()


#   hubot pager stfu|down <service,service,service> for <duration> [because <reason>]
  robot.respond (
    /pager (?:stfu|down) (.+) for ([0-9]+)(?:\s?m(?:in(?:utes?)?)?)?(?: because (.+))?\s*$/
  ), 'pager_set_maintenance_per_service', (res) ->
    [_, services, duration, description ] = res.match
    if services in ['*', 'all']
      services_list = []
    else
      services_list = services.split(',')
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.addMaintenance(res.envelope.user, duration, description, services_list)
    .then (data) ->
      end_time = moment(data.maintenance_window.end_time).utc().format('ddd HH:mm')
      res.send "Maintenance created for #{services} until #{end_time} UTC " +
               "(id #{data.maintenance_window.id})."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager stfu|down [for] [duration=60] [because <reason>] - creates a maintenance
  robot.respond (
    /pager (?:stfu|down)(?: for)?\s*([0-9]+)?(?:\s?m(?:in(?:utes?)?)?)?(?: because (.+))?\s*$/
  ), 'pager_set_maintenance', (res) ->
    [ _, duration, description ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.addMaintenance(res.envelope.user, duration, description)
    .then (data) ->
      end_time = moment(data.maintenance_window.end_time).utc().format('ddd HH:mm')
      res.send "Maintenance created for all services until #{end_time} UTC " +
               "(id #{data.maintenance_window.id})."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager end[s] <maintenance> - ends <maintenance>
  robot.respond /pager (?:end(?:s)?) ([A-Z0-9]+)\s*$/, 'pager_end_maintenance', (res) ->
    [ _, maintenance ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.endMaintenance(res.envelope.user, maintenance)
    .then (data) ->
      res.send 'Maintenance ended.'
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager me now            - creates an override until the end of current oncall
  robot.respond /pager (?:([^ ]+) )?now\s*$/, 'pager_override_now', (res) ->
    [ _, who ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.setOverride(res.envelope.user, { name: who })
    .then (data) ->
      res.send "Rejoice #{data.over.from}! #{data.over.name} is now on call."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager not me            - cancels an override if any
  robot.respond /pager not ([^ ]+)\s*$/, 'pager_cancel_override', (res) ->
    [ _, who ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.dropOverride(res.envelope.user, { name: who })
    .then (data) ->
      if data
        if who is 'me'
          who = 'your'
        res.send "Ok, #{res.envelope.user.name}! #{who} override is cancelled."
      else
        if who is 'me'
          who = 'you'
        res.send "Sorry there is no overrides for '#{who}' at the moment."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager me next - creates an override for the next scheduled
  robot.respond /pager ([^ ]+) next\s*$/, 'pager_override_next', (res) ->
    [ _, who] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.getFirstOncall()
    .then (data) ->
      startDate = moment(data.end).utc()
      pagerv2.setOverride(res.envelope.user, { name: who }, 0, startDate)
    .then (data) ->
      endDate = moment(data.over.end).utc().format('dddd HH:mm')
      startDate = moment(data.over.start).utc().format('dddd HH:mm')
      res.send "Rejoice #{data.over.from}! #{data.over.name} " +
               "will be on call from #{startDate} to #{endDate} (utc)"
    .catch (e) ->
      res.send(e)
    res.finish()

#   hubot pager me <duration>     - creates an override for <duration> minutes
  robot.respond (
    /pager (?:([^ ]+) )?(?:for )?(\d+)(?: min(?:utes?)?)?\s*$/
  ), 'pager_override', (res) ->
    [ _, who, duration ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      pagerv2.setOverride(res.envelope.user, { name: who }, duration)
    .then (data) ->
      res.send "Rejoice #{data.over.from}! #{data.over.name} is now on call."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pager add <me|user_nick> [to all] [[with] message] -\
#   add caller for responder on incidents
  robot.respond /pager add (me|[^ ]+)(?: to all)(?: with )?(.+)?\s*$/, 'pager_request_all', (res) ->
    [ _, who, msg ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      if who is 'me'
        who = res.envelope.user.name
      pagerv2.requestResponderIncidents(res.envelope.user, who, '', msg)
      .then (data) ->
        plural = ''
        if data.length > 1
          plural = 's'
        res.send "Incident#{plural} "+
                 "#{data.map( (r) -> r.responder_request.incident.id).join(', ')} " +
                 "responder #{who} requested."
    .catch (e) ->
      res.send e.message or e
    res.finish()

# hubot pager add me to <#,#,#> [[with] msg] - add responder caller incidents <#,#,#>
# hubot pager add <user,user,user> to <#,#,#> [[with] msg] - add responder user to incidents <#,#,#>
  robot.respond (
    /pager add (me|[^ ]+) to #?([A-Z0-9,]+)(?: ?with )?(.+)?\s*$/
  ), 'pager_assign_one', (res) ->
    [ _, who, incidents, msg ] = res.match
    pagerv2.getPermission(res.envelope.user, 'pageruser')
    .then ->
      if who is 'me'
        who = res.envelope.user.name
      pagerv2.requestResponderIncidents(res.envelope.user, who, incidents, msg)
    .then (data) ->
      plural = ''
      if data.length > 1
        plural = 's'
      res.send "Incident#{plural} "+
               "#{data.map( (r) -> r.responder_request.incident.id).join(', ')} " +
               "responder #{who} requested."
    .catch (e) ->
      res.send e.message or e
    res.finish()
