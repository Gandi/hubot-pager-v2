# Description:
#   enable communication with Pagerduty using API v2
#
# Dependencies:
#
# Configuration:
#
# Commands:
#   hubot pd version           - give the version of hubot-pager-v2 loaded
#   hubot pd me                - check if the caller is known by pagerduty plugin
#   hubot pd me as <email>     - declare what email should be use to find caller pagerduty id
#   hubot pd <user> as <email> - declare what email should be use to find <user> pagerduty id
#   hubot pd me <duration>     - creates an override
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

# TODO
#   hubot pd me as <email> - declare what email should be use to find user pagerduty id
  robot.respond /pd me as ([^\s@]+@[^\s]+)\s*$/, (res) ->
    [ _, email ] = res.match
    res.send "Not yet implemented"

# TODO
#   hubot pd <user> as <email> - declare what email should be use to find <user> pagerduty id
  robot.respond /pd ([^\s]+) as ([^\s@]+@[^\s]+)\s*$/, (res) ->
    # need admin perms
    [ _, who, email ] = res.match
    res.send "Not yet implemented"
