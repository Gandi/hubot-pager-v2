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
    process.env.PAGERV2_ANNOUNCE_ROOM = "#dev"
    process.env.PORT = 8088
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

  # ---------------------------------------------------------------------------------
  context.only 'it is not a task', ->
    beforeEach ->
      @postData = '{
        "storyID": "7373",
        "storyType": "PhabricatorApplicationTransactionFeedStory",
        "storyData": {
          "objectPHID": "PHID-PSTE-m4pqx64n2dtrwplk7qkh",
          "transactionPHIDs": {
            "PHID-XACT-PSTE-zmss7ubkaq5pzor": "PHID-XACT-PSTE-zmss7ubkaq5pzor"
          }
        },
        "storyAuthorPHID": "PHID-USER-7p4d4k6v4csqx7gcxcbw",
        "storyText": "ash created P6 new test paste.",
        "epoch": "1469408232"
      }'

    afterEach ->
      room.destroy()

    it 'should not react', ->
      expected = {
        message: 'mose triaged T2569: setup webhooks as High priority.',
        rooms: [ ]
      }
      pagerv2 = new Pagerv2 room.robot
      pagerv2.parseWebhook('console', require('./fixtures/webhook_trigger.json'))
      .then (announce) ->
        expect(announce).to.eql expected
      .catch (e) ->
        expect(e).to.eql 'no room to announce in'
