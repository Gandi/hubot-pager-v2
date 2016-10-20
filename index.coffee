path = require 'path'

features = [
  'commands'
]

module.exports = (robot) ->
  for feature in features
    robot.logger.debug "Loading pagerv2_#{feature}"
    robot.loadFile(path.resolve(__dirname, 'scripts'), "pagerv2_#{feature}.coffee")
