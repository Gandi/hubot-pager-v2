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

    # Webhook listener
    if pagerEndpoint and pagerAnnounceRoom
      robot.router.post pagerEndpoint, (req, res) ->
        if req.body? and req.body.messages? and req.body.messages[0].type?
          robot.logger.debug req.body
          if /^incident.*$/.test(req.body.messages[0].type)
            pagerv2.parseWebhook(robot.adapter.name, req.body.messages)
            .then (messages) ->
              for message in messages
                robot.messageRoom pagerRoom, message
          else
            robot.logger.warning '[pagerv2] Invalid hook payload ' +
                                 "type #{req.body.messages[0].type} from #{req.ip}"
        else
            robot.logger.warning "[pagerv2] Invalid hook payload from #{req.ip}"

        res.end()
