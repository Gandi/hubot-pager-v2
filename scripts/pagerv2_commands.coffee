# Description:
#   enable communication with Pagerduty using API v2
#
# Dependencies:
#
# Configuration:
#
# Commands:
#   hubot pd version             - give the version of hubot-pager-v2 loaded
#
#   hubot pd me                  - check if the caller is known by pagerduty plugin
#   hubot pd me as <email>       - declare what email should be use to find caller pagerduty id
#   hubot pd <user> as <email>   - declare what email should be use to find <user> pagerduty id
#
#   hubot pd noc <duration>      - creates an override for <duration> minutes with the noc account
#   hubot pd noc now             - creates a noc  override until the end of current oncall
#   hubot pd not noc             - cancels a noc override if any
#
#   hubot pd incident <#>        - gives more information about incident number <number>
#   hubot pd sup|inc|incidents   - lists currently unresolved incidents
#
#   hubot pd ack [all]           - acknowledges any unack incidents
#   hubot pd ack <#,#,#>         - acknowledges incident <number>
#
#   hubot pd res|resolve [all]   - resolves any un-resolved incidents
#   hubot pd res|resolve <#,#,#> - resolves incident <number>
#
#   hubot pd snooze [all] [for] [<duration>] [min]   - snoozes any open incidents
#   hubot pd snooze <#,#,#> [for] [<duration>] [min] - snoozes incident <number>
#
#   hubot pd assign [all] to me       - assigns all open incidents to caller
#   hubot pd assign [all] to <user>   - assigns all open incidents to user
#   hubot pd assign <#,#,#> to me     - assigns incidents <#,#,#> to caller
#   hubot pd assign <#,#,#> to <user> - assigns incidents <#,#,#> to user
#
#   hubot pd note <#,#,#> <note> - create a note for incidents <#,#,#>
#   hubot pd notes <#>           - read notes for incident <#>
#
#   hubot pd [who is] oncall        - tells who is currently on call
#   hubot pd [who is] next [oncall] - tells who is next on call
#   hubot pd escalation             - tells who is involved in the escalation process
#
#   hubot pd maintenances           - lists currently active maintenances
#   hubot pd stfu|down [for] <duration> [because <reason>] - creates a maintenance
#   hubot pd up|end|back <maintenance> - ends <maintenance>
#
#   hubot pd schedules [<search>]   - lists schedules (optionaly filtered by <search>)
#
#   hubot pd me <duration>       - creates an override for <duration> minutes
#   hubot pd me now              - creates an override until the end of current oncall
#   hubot pd not me              - cancels an override if any
#
# Author:
#   mose

Pagerv2 = require '../lib/pagerv2'
moment = require 'moment'
path = require 'path'

module.exports = (robot) ->

  robot.brain.data.pagerv2 ?= { users: { } }
  robot.pagerv2 ?= new Pagerv2 robot, process.env
  pagerv2 = robot.pagerv2
  # console.log robot.pagerv2.data

#   hubot pd version - give the version of hubot-pager-v2 loaded
  robot.respond /pd version\s*$/, 'pd_version', (res) ->
    pkg = require path.join __dirname, '..', 'package.json'
    res.send "hubot-pager-v2 is version #{pkg.version}"
    res.finish()

#   hubot pd me - check if the caller is known by pagerduty plugin
  robot.respond /pd me\s*$/, (res) ->
    pagerv2.getUser(res.envelope.user, res.envelope.user)
    .then (data) ->
      res.send "Oh I know you, you are #{data}."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd me as <email> - declare what email should be use to find user pagerduty id
  robot.respond /pd me as ([^\s@]+@[^\s]+)\s*$/, 'pd_me_as', (res) ->
    [ _, email ] = res.match
    pagerv2.setUser(res.envelope.user, email)
    .then (data) ->
      res.send "Ok now I know you are #{data}."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd <user> as <email> - declare what email should be use to find <user> pagerduty id
  robot.respond /pd ([^\s]+) as ([^\s@]+@[^\s]+)\s*$/, 'pd_user_as', (res) ->
    who = null
    pagerv2.getPermission(res.envelope.user, 'pdadmin')
    .then ->
      [ _, who, email ] = res.match
      pagerv2.setUser(who, email)
    .bind(who)
    .then (data) ->
      res.send "Ok now I know #{who} is #{data}."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd oncall - returns who is on call
  robot.respond /(?:pd )?(?:who(?: is|'s) )?on ?call\s*$/, 'pd_oncall', (res) ->
    pagerv2.getOncall()
    .then (data) ->
      nowDate = moment().utc()
      endDate = moment(data.end).utc()
      if nowDate.isSame(endDate, 'day')
        endDate = endDate.format('HH:mm')
      else
        endDate = endDate.format('dddd HH:mm')
      res.send "#{data.user.summary} is on call until #{endDate} (utc)."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd [who is] next [oncall] - tells who is next on call
  robot.respond (
    /(?:pd )?(?:who(?: is|'s) )?(next on ?call|on ?call next)\s*$/
  ), 'pd_next_oncall', (res) ->
    pagerv2.getOncall()
    .then (data) ->
      fromtime = moment(data.end).utc().add(1, 'minute').format()
      pagerv2.getOncall(fromtime)
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

# TODO
#   hubot pd escalation          - tells who is involved in the escalation process
  robot.respond /pd escalation\s+$/, 'pd_escalation', (res) ->
    res.send 'Not yet implemented'
    res.finish()

#   hubot pd incident <number> - gives more information about incident number <number>
  robot.respond /pd (?:inc |incident )(\d+|[A-Z0-9]{7})\s*$/, 'pd_incident', (res) ->
    [ _, incident ] = res.match
    pagerv2.getIncident(incident)
    .then (data) ->
      res.send "#{data.incident.id} (#{data.incident.status}) #{data.incident.summary}"
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd sup|inc|incidents - lists currently unresolved incidents
  robot.respond /pd (?:sup|inc(?:idents))\s*$/, 'pd_incidents', (res) ->
    pagerv2.listIncidents()
    .then (data) ->
      for inc in data.incidents
        res.send "#{inc.id} (#{inc.status}) #{inc.summary}"
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd ack               - acknowledges any unack incidents
  robot.respond /pd ack(?: all)?\s*$/, 'pd_ack_all', (res) ->
    pagerv2.updateIncidents(res.envelope.user)
    .then (data) ->
      plural = ''
      if data.incidents.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')} acknowledged."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd ack <#>           - acknowledges incident <number>
  robot.respond /pd ack (.+)\s*$/, 'pd_ack_one', (res) ->
    [ _, incidents ] = res.match
    pagerv2.updateIncidents(res.envelope.user, incidents)
    .then (data) ->
      plural = ''
      if data.incidents.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')} acknowledged."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd res|resolve       - acknowledges any unack incidents
  robot.respond /pd res(?:olve)?(?: all)?\s*$/, 'pd_res_all', (res) ->
    pagerv2.updateIncidents(res.envelope.user, '', 'acknowledged', 'resolved')
    .then (data) ->
      plural = ''
      if data.incidents.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')} resolved."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pd res|resolve <#>   - acknowledges incident <number>
  robot.respond /pd res(?:olve)? (.+)\s*$/, 'pd_res_one', (res) ->
    [ _, incidents ] = res.match
    pagerv2.updateIncidents(res.envelope.user, incidents, 'acknowledged', 'resolved')
    .then (data) ->
      plural = ''
      if data.incidents.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')} resolved."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pd assign [all] to me       - assigns all open incidents to caller
#   hubot pd assign [all] to <user>   - assigns all open incidents to user
  robot.respond /pd assign(?: all) to (me|[^ ]+)\s*$/, 'pd_assign_all', (res) ->
    [ _, who ] = res.match
    if who is 'me'
      who = res.envelope.user.name
    pagerv2.assignIncidents(res.envelope.user, who)
    .then (data) ->
      plural = ''
      if data.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')} " +
               "assigned to #{who}."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pd assign <#,#,#> to me     - assigns incidents <#,#,#> to caller
#   hubot pd assign <#,#,#> to <user> - assigns incidents <#,#,#> to user
  robot.respond /pd assign (.+) to (me|[^ ]+)\s*$/, 'pd_assign_one', (res) ->
    [ _, incidents, who ] = res.match
    if who is 'me'
      who = res.envelope.user.name
    pagerv2.assignIncidents(res.envelope.user, who, incidents)
    .then (data) ->
      plural = ''
      if data.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.incidents.map( (e) -> e.id).join(', ')} " +
               "assigned to #{who}."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pd snooze [all] [for] [<duration>] [min]  - acknowledges any unack incidents
  robot.respond (
    /pd snooze(?: all)?(?: (?:for )(\d+)(?: min(?:utes)?)?)?\s*$/
  ), 'pd_snooze_all', (res) ->
    [ _, duration ] = res.match
    pagerv2.snoozeIncidents(res.envelope.user, '', duration)
    .then (data) ->
      plural = ''
      if data.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.map( (e) -> e.incident.id).join(', ')} snoozed."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pd snooze <#,#,#> [for] [<duration>] [min] - acknowledges incident <number>
  robot.respond (
    /pd snooze (.+)(?: (?:for )(\d+)(?: min(?:utes)?)?)?\s*$/
  ), 'pd_snooze_one', (res) ->
    [ _, incidents, duration ] = res.match
    pagerv2.snoozeIncidents(res.envelope.user, incidents, duration)
    .then (data) ->
      plural = ''
      if data.length > 1
        plural = 's'
      res.send "Incident#{plural} #{data.map( (e) -> e.incident.id).join(', ')} snoozed."
    .catch (e) ->
      res.send e.message or e
    res.finish()

#   hubot pd note <#,#,#> <note> - create a note for incidents <#,#,#>
  robot.respond /pd note ([^\s]+) (.*)$/, 'pd_note', (res) ->
    [ _, incident, note ] = res.match
    pagerv2.addNote(res.envelope.user, incident, note)
    .then (data) ->
      res.send "Note added to #{incident}: #{note}."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd notes <#>           - read notes for incident <#>
  robot.respond /pd notes ([^\s]+)\s*$/, 'pd_notes', (res) ->
    [ _, incident ] = res.match
    pagerv2.listNotes(incident)
    .then (data) ->
      for note in data.notes
        res.send "#{incident} - #{note.content}"
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd maintenances           - lists currently active maintenances
  robot.respond /pd maintenances?\s*$/, 'pd_maintenances', (res) ->
    pagerv2.listMaintenances()
    .then (data) ->
      for maintenance in data.maintenance_windows
        end = moment(maintenance.end_time).utc().format('HH:mm')
        res.send "#{maintenance.id} - #{maintenance.summary} (until #{end} UTC)"
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd stfu|down [for] <duration> [because <reason>] - creates a maintenance
  robot.respond (
    /pd (?:stfu|down)(?: for)?\s*([0-9]+)?(?: min(?:utes)?)?(?: because (.+))?\s*$/
  ), 'pd_set_maintenance', (res) ->
    [ _, duration, description ] = res.match
    pagerv2.addMaintenance(res.envelope.user, duration, description)
    .then (data) ->
      end_time = moment(data.maintenance_window.end_time).utc().format('HH:mm')
      res.send "Maintenance created for all services until #{end_time} UTC " +
               "(id #{data.maintenance_window.id})."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd up|end|back <maintenance> - ends <maintenance>
  robot.respond /pd (?:up|back|end) ([A-Z0-9]+)\s*$/, 'pd_end_maintenance', (res) ->
    [ _, maintenance ] = res.match
    pagerv2.endMaintenance(res.envelope.user, maintenance)
    .then (data) ->
      res.send 'Maintenance ended.'
    .catch (e) ->
      res.send e
    res.finish()

# TODO
#   hubot pd schedules [<search>]   - lists schedules (optionaly filtered by <search>)
  robot.respond /pd sched(?:ules?)?(?: ([A-Z0-9]+))?\s*$/, 'pd_schedules', (res) ->
    [ _, filter ] = res.match
    res.send 'Not yet implemented'
    res.finish()

#   hubot pd me now            - creates an override until the end of current oncall
  robot.respond /pd (?:([^ ]+) )?now\s*$/, 'pd_override_now', (res) ->
    [ _, who ] = res.match
    pagerv2.setOverride(res.envelope.user, who)
    .then (data) ->
      res.send "Rejoice #{data.user.summary}! #{data.over.name} is now on call."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd not me            - cancels an override if any
  robot.respond /pd not ([^ ]+)\s*$/, 'pd_cancel_override', (res) ->
    [ _, who ] = res.match
    pagerv2.dropOverride(res.envelope.user, who)
    .then (data) ->
      res.send "Ok, #{res.envelope.user.name}! " +
               "#{data.overrides[0].user.summary} override is cancelled."
    .catch (e) ->
      res.send e
    res.finish()

#   hubot pd me <duration>     - creates an override for <duration> minutes
  robot.respond /pd (?:([^ ]+) )?(?:for )?(\d+)(?: min(?:utes)?)?\s*$/, 'pd_override', (res) ->
    [ _, who, duration ] = res.match
    pagerv2.setOverride(res.envelope.user, who, duration)
    .then (data) ->
      res.send "Rejoice #{data.user.summary}! #{data.over.name} is now on call."
    .catch (e) ->
      res.send e
    res.finish()
