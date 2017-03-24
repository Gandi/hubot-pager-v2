require('es6-promise').polyfill()

Helper = require('hubot-test-helper')

# helper loads a specific script if it's a file
helper = new Helper('../scripts/pagerv2_hook.coffee')
Pagerv2 = require '../lib/pagerv2'

http        = require('http')
nock        = require('nock')
sinon       = require('sinon')
chai        = require('chai')
chai.use(require('sinon-chai'))
expect      = chai.expect
querystring = require('querystring')
room = null

describe 'phabs_feeds module', ->

  hubotHear = (message, userName = 'momo', tempo = 40) ->
    beforeEach (done) ->
      room.user.say userName, message
      setTimeout (done), tempo

  hubot = (message, userName = 'momo') ->
    hubotHear "@hubot #{message}", userName

  hubotResponse = (i = 1) ->
    room.messages[i]?[1]

  hubotResponseCount = ->
    room.messages.length

  beforeEach ->
    process.env.PAGERV2_API_KEY = 'xxx'
    process.env.PAGERV2_SCHEDULE_ID = '42'
    process.env.PAGERV2_ANNOUNCE_ROOM = '#dev'
    process.env.PORT = 8089
    room = helper.createRoom()
    room.robot.brain.userForId 'user', {
      name: 'user'
    }
    room.robot.brain.userForId 'user_with_email', {
      name: 'user_with_email',
      email_address: 'user@example.com'
    }
    room.robot.brain.userForId 'user_with_phid', {
      name: 'user_with_phid',
      phid: 'PHID-USER-123456789'
    }

  afterEach ->
    delete process.env.PAGERV2_API_KEY
    delete process.env.PAGERV2_SCHEDULE_ID
    delete process.env.PAGERV2_ANNOUNCE_ROOM
    room.destroy()


# -------------------------------------------------------------------------------------------------
  context 'it is a trigger message', ->

    it 'should react', ->
      expected = [
        '[undefined] CPU Load High on xdb_production_echo - trigger (Laura Haley)'
      ]
      pagerv2 = new Pagerv2 room.robot
      pagerv2.parseWebhook(
        'console',
        require('./fixtures/webhook_trigger.json').messages
      ).then (announce) ->
        expect(announce).to.eql expected

# -------------------------------------------------------------------------------------------------
  context 'it is a resolve message', ->

    it 'should react', ->
      expected = [
        '[undefined] CPU Load High on xdb_production_echo - resolve (Wiley Jacobson)'
      ]
      pagerv2 = new Pagerv2 room.robot
      pagerv2.parseWebhook(
        'console',
        require('./fixtures/webhook_resolve.json').messages
      ).then (announce) ->
        expect(announce).to.eql expected
