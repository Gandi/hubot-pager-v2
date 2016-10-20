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
# Author:
#   mose

Pagerv2 = require '../lib/pagerv2'
moment = require 'moment'
path = require 'path'

module.exports = (robot) ->

  robot.pagerv2 ?= new Pagerv2 robot, process.env
  pagerv2 = robot.pagerv2

#   hubot pd version - give the version of hubot-pager-v2 loaded
  robot.respond /pd version\s*$/, (res) ->
    pkg = require path.join __dirname, '..', 'package.json'
    res.send "hubot-pager-v2 is version #{pkg.version}"
    res.finish()

# TODO
#   hubot pd me - check if the caller is known by pagerduty plugin
  robot.respond /pd me\s*$/, (res) ->
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd me as <email> - declare what email should be use to find user pagerduty id
  robot.respond /pd me as ([^\s@]+@[^\s]+)\s*$/, (res) ->
    [ _, email ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd <user> as <email> - declare what email should be use to find <user> pagerduty id
  robot.respond /pd ([^\s]+) as ([^\s@]+@[^\s]+)\s*$/, (res) ->
    # need admin perms
    [ _, who, email ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd me <duration>     - creates an override for <duration> minutes
#   hubot pd noc <duration>    - creates an override for <duration> minutes
  robot.respond /pd (me|noc) (\d+)(?: min(?:utes)?)?\s*$/, (res) ->
    [ _, who, duration ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd me now            - creates an override until the end of current oncall
#   hubot pd noc now           - creates an override until the end of current oncall
  robot.respond /pd (me|noc) now\s*$/, (res) ->
    [ _, who ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd not me            - cancels an override if any
#   hubot pd not noc           - cancels an override if any
  robot.respond /pd not (me|noc)\s*$/, (res) ->
    [ _, who ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd <number>          - gives more information about incident number <number>
  robot.respond /pd (\d+)\s*$/, (res) ->
    [ _, incident ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd sup|inc|incidents - lists currently unresolved incidents
  robot.respond /pd (?:sup|inc(?:idents))\s*$/, (res) ->
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd ack               - acknowledges any unack incidents
  robot.respond /pd ack(?: all)?\s*$/, (res) ->
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd ack <#>           - acknowledges incident <number>
  robot.respond /pd ack ([\d, ]+)\s*$/, (res) ->
    [ _, incidents ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd res|resolve       - acknowledges any unack incidents
  robot.respond /pd res(?:olve)?(?: all)?\s*$/, (res) ->
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd res|resolve <#>   - acknowledges incident <number>
  robot.respond /pd res(?:olve)? ([\d, ]+)\s*$/, (res) ->
    [ _, incidents ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd snooze [all] [for] [<duration>] [min]  - acknowledges any unack incidents
  robot.respond /pd snooze(?: all)?(?: (?:for )(\d+)(?: min(?:utes)?)?)?\s*$/, (res) ->
    [ _, duration ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd snooze <#,#,#> [for] [<duration>] [min] - acknowledges incident <number>
  robot.respond /pd snooze ([\d, ]+)(?: (?:for )(\d+)(?: min(?:utes)?)?)?\s*$/, (res) ->
    [ _, incidents, duration ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd assign [all] to me       - assigns all open incidents to caller
#   hubot pd assign [all] to <user>   - assigns all open incidents to user
  robot.respond /pd assign(?: all) to (me|[^ ]+)\s*$/, (res) ->
    [ _, who ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd assign <#,#,#> to me     - assigns incidents <#,#,#> to caller
#   hubot pd assign <#,#,#> to <user> - assigns incidents <#,#,#> to user
  robot.respond /pd assign ([\d, ]+) to (me|[^ ]+)\s*$/, (res) ->
    [ _, incidents, who ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd note <#,#,#> <note> - create a note for incidents <#,#,#>
  robot.respond /pd note ([\d, ]+) ([^\s].*)$/, (res) ->
    [ _, incidents, note ] = res.match
    res.send "Not yet implemented"
    res.finish()

# TODO
#   hubot pd notes <#>           - read notes for incident <#>
  robot.respond /pd notes ([\d, ]+)\s+$/, (res) ->
    [ _, incident ] = res.match
    res.send "Not yet implemented"
    res.finish()
