# Description:
#   webhook endpoint for Pagerduty
#
# Dependencies:
#
# Configuration:
#   PAGERV2_ENDPOINT
#   PAGERV2_ANNOUNCE_ROOM
#
# Commands:
#
# Author:
#   mose

Pagerv2 = require '../lib/pagerv2'
moment = require 'moment'
path = require 'path'


module.exports = (robot) ->

  robot.brain.on 'loaded', ->

    pagerEndpoint = process.env.PAGERV2_ENDPOINT or '/hook'
    pagerAnnounceRoom = process.env.PAGERV2_ANNOUNCE_ROOM

    robot.brain.data.pagerv2 ?= {
      users: { }
    }
    robot.pagerv2 ?= new Pagerv2 robot, process.env
    pagerv2 = robot.pagerv2
    # console.log robot.pagerv2.data

    # Webhook listener
    if pagerEndpoint and pagerAnnounceRoom
      robot.router.post pagerEndpoint, (req, res) ->
        robot.logger.debug req.body
        pagerv2.parseWebhook(req.body, pagerRoom, res)
        res.end()
