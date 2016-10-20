# Description:
#   handles communication with PagerDuty API v2
#
# Dependencies:
#
# Configuration:
#  PAGERV2_API_KEY
#
# Author:
#   mose

Promise = require 'bluebird'

class Pagerv2

  constructor: (@robot, env) ->
    storageLoaded = =>
      @data = @robot.brain.data.pagerdutyv2 ||= {
        users: { }
      }
      @robot.logger.debug 'Pagerduty V2 Data Loaded: ' + JSON.stringify(@data, null, 2)
    @robot.brain.on 'loaded', storageLoaded
    storageLoaded()



module.exports = Pagerv2
