# Description:
#   enable communication with Pagerduty using API v2
#
# Dependencies:
#
# Configuration:
#
# Commands:
#   hubot pd version - give the version of hubot-phabs loaded
#
# Author:
#   mose

PagerDutyV2 = require '../lib/pagerduty_v2'
moment = require 'moment'
path = require 'path'

module.exports = (robot) ->
  
  robot.pager ?= new PagerDutyV2 robot, process.env
  pager = robot.pager

  #   hubot pd version - give the version of hubot-pager-v2 loaded
  robot.respond /pd version *$/, (msg) ->
    pkg = require path.join __dirname, '..', 'package.json'
    msg.send "hubot-pager-v2 module is version #{pkg.version}"
    msg.finish()
