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
https = require 'https'
querystring = require 'querystring'

class Pagerv2

  constructor: (@robot, env) ->
    storageLoaded = =>
      @data = @robot.brain.data.pagerv2 ||= {
        users: { }
      }
      @robot.logger.debug 'Pagerduty V2 Data Loaded: ' + JSON.stringify(@data, null, 2)
    @robot.brain.on 'loaded', storageLoaded
    storageLoaded()

  request: (method, endpoint, query) =>
    return new Promise (res, err) ->
      if process.env.PAGERV2_API_KEY?
        auth = "Token token=#{process.env.PAGERV2_API_KEY}"
        body = querystring.stringify(query)
        options = 
          hostname: 'api.pagerduty.com'
          post: 443
          method: method
          path: endpoint
          headers:
            Authorization: auth
            Accept: 'application/vnd.pagerduty+json;version=2'
        req = https.request options, (response) ->
          data = ''
          response.on 'data', (chunk) ->
            data += chunk
          response.on 'end', ->
            res JSON.parse(data)
        req.end()
        req.on 'error', (error) =>
          err "#{error.code} #{error.message}"
      else
        err "PAGERV2_API_KEY is not set in your environment."


module.exports = Pagerv2
