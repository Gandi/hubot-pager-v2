# Description:
#   enable communication with Pagerduty using API v2
#
# Dependencies:
#
# Configuration:
#
# Commands:
#   hubot pd version - give the version of hubot-pager-v2 loaded
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
  robot.respond /pd version *$/, (res) ->
    pkg = require path.join __dirname, '..', 'package.json'
    res.send "hubot-pager-v2 is version #{pkg.version}"
    res.finish()
