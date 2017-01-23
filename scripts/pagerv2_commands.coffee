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
#   hubot pd me <duration>       - creates an override for <duration> minutes
#   hubot pd me now              - creates an override until the end of current oncall
#   hubot pd not me              - cancels an override if any
#
#   hubot pd noc <duration>      - creates an override for <duration> minutes with the noc account
#   hubot pd noc now             - creates a noc  override until the end of current oncall
#   hubot pd not noc             - cancels a noc override if any
#
#   hubot pd <#>                 - gives more information about incident number <number>
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
# Author:
#   mose

Pagerv2 = require '../lib/pagerv2'
moment = require 'moment'
path = require 'path'

module.exports = (robot) ->

  robot.brain.on 'loaded', ->

    robot.brain.data.pagerv2 ?= {
      users: { }
    }
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
    robot.respond /pd me as ([^\s@]+@[^\s]+)\s*$/, (res) ->
      [ _, email ] = res.match
      pagerv2.setUser(res.envelope.user, email)
      .then (data) ->
        res.send "Ok now I know you are #{data}."
      .catch (e) ->
        res.send e
      res.finish()

  #   hubot pd <user> as <email> - declare what email should be use to find <user> pagerduty id
    robot.respond /pd ([^\s]+) as ([^\s@]+@[^\s]+)\s*$/, (res) ->
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
    robot.respond /(?:pd )?oncall\s*$/, (res) ->
      pagerv2.getSchedule()
      .then (data) ->
        nowDate = moment().utc()
        endDate = moment(data.end)
        if nowDate.isSame(endDate, 'day')
          endDate = endDate.format('HH:mm')
        else
          endDate = endDate.format('dddd HH:mm')
        res.send "#{data.user.summary} is on call until #{endDate}."
      .catch (e) ->
        res.send e
      res.finish()

  #   hubot pd me <duration>     - creates an override for <duration> minutes
    robot.respond /pd (?:([^ ]+) )?(?:for )?(\d+)(?: min(?:utes)?)?\s*$/, (res) ->
      [ _, who, duration ] = res.match
      pagerv2.setOverride(res.envelope.user, who, duration)
      .then (data) ->
        res.send "Rejoice #{data.user.summary}! #{data.over.name} is now on call."
      .catch (e) ->
        res.send e
      res.finish()

  # TODO
  #   hubot pd me now            - creates an override until the end of current oncall
    robot.respond /pd (?:([^ ]+) )?now\s*$/, (res) ->
      [ _, who ] = res.match
      pagerv2.setOverride(res.envelope.user, who, false)
      .then (data) ->
        res.send "Rejoice #{data.user.summary}! #{data.over.name} is now on call."
      .catch (e) ->
        res.send e
      res.finish()

  # TODO
  #   hubot pd not me            - cancels an override if any
    robot.respond /pd not (me|noc)\s*$/, (res) ->
      [ _, who ] = res.match
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd <number>          - gives more information about incident number <number>
    robot.respond /pd (\d+)\s*$/, (res) ->
      [ _, incident ] = res.match
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd sup|inc|incidents - lists currently unresolved incidents
    robot.respond /pd (?:sup|inc(?:idents))\s*$/, (res) ->
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd ack               - acknowledges any unack incidents
    robot.respond /pd ack(?: all)?\s*$/, (res) ->
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd ack <#>           - acknowledges incident <number>
    robot.respond /pd ack ([\d, ]+)\s*$/, (res) ->
      [ _, incidents ] = res.match
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd res|resolve       - acknowledges any unack incidents
    robot.respond /pd res(?:olve)?(?: all)?\s*$/, (res) ->
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd res|resolve <#>   - acknowledges incident <number>
    robot.respond /pd res(?:olve)? ([\d, ]+)\s*$/, (res) ->
      [ _, incidents ] = res.match
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd snooze [all] [for] [<duration>] [min]  - acknowledges any unack incidents
    robot.respond /pd snooze(?: all)?(?: (?:for )(\d+)(?: min(?:utes)?)?)?\s*$/, (res) ->
      [ _, duration ] = res.match
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd snooze <#,#,#> [for] [<duration>] [min] - acknowledges incident <number>
    robot.respond /pd snooze ([\d, ]+)(?: (?:for )(\d+)(?: min(?:utes)?)?)?\s*$/, (res) ->
      [ _, incidents, duration ] = res.match
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd assign [all] to me       - assigns all open incidents to caller
  #   hubot pd assign [all] to <user>   - assigns all open incidents to user
    robot.respond /pd assign(?: all) to (me|[^ ]+)\s*$/, (res) ->
      [ _, who ] = res.match
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd assign <#,#,#> to me     - assigns incidents <#,#,#> to caller
  #   hubot pd assign <#,#,#> to <user> - assigns incidents <#,#,#> to user
    robot.respond /pd assign ([\d, ]+) to (me|[^ ]+)\s*$/, (res) ->
      [ _, incidents, who ] = res.match
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd note <#,#,#> <note> - create a note for incidents <#,#,#>
    robot.respond /pd note ([\d, ]+) ([^\s].*)$/, (res) ->
      [ _, incidents, note ] = res.match
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd notes <#>           - read notes for incident <#>
    robot.respond /pd notes ([\d, ]+)\s+$/, (res) ->
      [ _, incident ] = res.match
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd [who is] oncall     - tells who is currently on call
    robot.respond /pd (?:who(?: is|'s) )?(?:on ?call)\s+$/, (res) ->
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd [who is] next [oncall] - tells who is next on call
    robot.respond /pd (?:who(?: is|'s) )?next(?: on ?call)?\s+$/, (res) ->
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd escalation          - tells who is involved in the escalation process
    robot.respond /pd escalation\s+$/, (res) ->
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd maintenances           - lists currently active maintenances
    robot.respond /pd maintenances?\s+$/, (res) ->
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd stfu|down [for] <duration> [because <reason>] - creates a maintenance
    robot.respond (
      /pd (?:stfu|down)(?: for)?\s*([0-9]+)?(?: min(?:utes)?)?(?: because (.+))?\s+$/
    ), (res) ->
      [ _, duration ] = res.match
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd up|end|back <maintenance> - ends <maintenance>
    robot.respond /pd (?:up|back|end) ([A-Z0-9]+)\s+$/, (res) ->
      [ _, maintenance ] = res.match
      res.send 'Not yet implemented'
      res.finish()

  # TODO
  #   hubot pd schedules [<search>]   - lists schedules (optionaly filtered by <search>)
    robot.respond /pd sched(?:ules?)?(?: ([A-Z0-9]+))?\s+$/, (res) ->
      [ _, filter ] = res.match
      res.send 'Not yet implemented'
      res.finish()
