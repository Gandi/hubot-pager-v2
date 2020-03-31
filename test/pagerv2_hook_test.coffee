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

describe 'pagerv2_hook module', ->

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
    process.env.PAGERV2_ENDPOINT = '/test_hook'
    process.env.PAGERV2_CUSTOM_ACTION_FILE = 'test/fixtures/custom_action.json'
    process.env.PORT = 8089
    room = helper.createRoom()
    room.robot.adapterName = 'console'

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
    delete process.env.PAGERV2_ENDPOINT
    delete process.env.PORT
    delete process.env.PAGERV2_CUSTOM_ACTION_FILE
    room.destroy()

# -------------------------------------------------------------------------------------------------
  context 'it is a trigger message', ->

    it 'should react', ->
      expected = [
        '[Production XDB Cluster] PRORDTY - CPU Load High on xdb_production_echo - ' +
        'trigger (Laura Haley)'
      ]
      pagerv2 = new Pagerv2 room.robot
      pagerv2.parseWebhook(
        'console',
        require('./fixtures/webhook_trigger.json').messages
      ).then (announce) ->
        expect(announce).to.eql expected

# --------------------------------------------------------------------------------------------------
  context 'it is a trigger message with webhook v2', ->

    it 'should react', ->
      expected = [
        '[Production XDB Cluster] PRORDTY - [#33] My new incident - ' +
        'trigger (Laura Haley,Jean Doe)'
      ]
      pagerv2 = new Pagerv2 room.robot
      pagerv2.parseWebhook(
        'console',
        require('./fixtures/webhook_v2_trigger.json').messages
      ).then (announce) ->
        expect(announce).to.eql expected
# -------------------------------------------------------------------------------------------------
  context 'it is a trigger message with empty subject but with a description', ->

    it 'should react', ->
      expected = [
        '[Production XDB Cluster] PRORDTY - something wrong - ' +
        'trigger (Laura Haley)'
      ]
      pagerv2 = new Pagerv2 room.robot
      pagerv2.parseWebhook(
        'console',
        require('./fixtures/webhook_trigger-no_subject-description.json').messages
      ).then (announce) ->
        expect(announce).to.eql expected


# -------------------------------------------------------------------------------------------------
  context 'it is a trigger message with empty subject', ->

    it 'should react', ->
      expected = [
        '[Production XDB Cluster] PRORDTY - (no subject) - ' +
        'trigger (Laura Haley)'
      ]
      pagerv2 = new Pagerv2 room.robot
      pagerv2.parseWebhook(
        'console',
        require('./fixtures/webhook_trigger-no_subject.json').messages
      ).then (announce) ->
        expect(announce).to.eql expected


# -------------------------------------------------------------------------------------------------
  context 'it is a trigger message without assigned user', ->
    context 'and a default resolver is set', ->
      beforeEach ->
        process.env.PAGERV2_DEFAULT_RESOLVER = 'monit system'
      afterEach ->
        delete process.env.PAGERV2_DEFAULT_RESOLVER

      it 'should react', ->
        expected = [
          '[Production XDB Cluster] PRORDTY - CPU Load High on xdb_production_echo - ' +
          'trigger (monit system)'
        ]
        pagerv2 = new Pagerv2 room.robot
        pagerv2.parseWebhook(
          'console',
          require('./fixtures/webhook_trigger_unassigned.json').messages
        ).then (announce) ->
          expect(announce).to.eql expected

# -------------------------------------------------------------------------------------------------
  context 'it is a trigger message without assigned user', ->
    context 'and no default resolver is set', ->
      it 'should react', ->
        expected = [
          '[Production XDB Cluster] PRORDTY - CPU Load High on xdb_production_echo - ' +
          'trigger (nagios)'
        ]
        pagerv2 = new Pagerv2 room.robot
        pagerv2.parseWebhook(
          'console',
          require('./fixtures/webhook_trigger_unassigned.json').messages
        ).then (announce) ->
          expect(announce).to.eql expected

# -------------------------------------------------------------------------------------------------
  context 'it is a resolve message', ->

    it 'should react', ->
      expected = [
        '[Production XDB Cluster] PRORDTY - CPU Load High on xdb_production_echo - ' +
        'resolve (Wiley Jacobson)'
      ]
      pagerv2 = new Pagerv2 room.robot
      pagerv2.parseWebhook(
        'console',
        require('./fixtures/webhook_resolve.json').messages
      ).then (announce) ->
        expect(announce).to.eql expected

# -------------------------------------------------------------------------------------------------
  context 'it is a resolve message with a slack adapter', ->

    it 'should react', ->
      expected = [
        '*[Production XDB Cluster]* PRORDTY - CPU Load High on xdb_production_echo - ' +
        'resolve (Wiley Jacobson)'
      ]
      pagerv2 = new Pagerv2 room.robot
      pagerv2.parseWebhook(
        'slack',
        require('./fixtures/webhook_resolve.json').messages
      ).then (announce) ->
        expect(announce).to.eql expected

# -------------------------------------------------------------------------------------------------
  context 'it is a resolve message with an irc adapter', ->

    it 'should react', ->
      expected = [
        '\u000303\u0002\u0002[Production XDB Cluster]\u0003 PRORDTY - CPU Load High on ' +
        'xdb_production_echo - resolve (Wiley Jacobson)'
      ]
      pagerv2 = new Pagerv2 room.robot
      pagerv2.parseWebhook(
        'irc',
        require('./fixtures/webhook_resolve.json').messages
      ).then (announce) ->
        expect(announce).to.eql expected
# -------------------------------------------------------------------------------------------------
  context 'it is a launch a custom action with an irc adapter', ->

    it 'should react', ->
      pagerv2 = new Pagerv2 room.robot
      answer = null
      room.robot.on 'pager_maintenance', (event) -> answer = event
      pagerv2.parseWebhook(
        'irc',
        require('./fixtures/webhook_custom_action_ok.json').messages
      ).then (announce) ->
        expect(answer).to.eql 'message=test'

# -------------------------------------------------------------------------------------------------
  context 'it is fail to run a custom action because of an unknown id', ->

    it 'should react', ->
      pagerv2 = new Pagerv2 room.robot
      expected = [ 'Unknown action for id 123' ]
      pagerv2.parseWebhook(
        'irc',
        require('./fixtures/webhook_custom_action_id_unknown.json').messages
      ).then (announce) ->
        expect(announce).to.eql expected

# -------------------------------------------------------------------------------------------------
  context 'it is fail to run a custom action because of bogus message', ->

    it 'should not react', ->
      pagerv2 = new Pagerv2 room.robot
      expected = [ 'Message parsing failed' ]
      pagerv2.parseWebhook(
        'irc',
        require('./fixtures/webhook_custom_action_ko.json').messages
      ).then (announce) ->
        expect(announce).to.eql expected




# -------------------------------------------------------------------------------------------------
  context 'it is a resolve message with an irc adapter but unknown type', ->

    it 'should react', ->
      expected = [
        '[Production XDB Cluster] PRORDTY - CPU Load High on xdb_production_echo - plouf (nagios)'
      ]
      pagerv2 = new Pagerv2 room.robot
      msg = require('./fixtures/webhook_resolve.json').messages
      msg[0].type = 'incident.plouf'
      pagerv2.parseWebhook('irc', msg)
      .then (announce) ->
        expect(announce).to.eql expected

# -------------------------------------------------------------------------------------------------
  context 'test the http responses', ->
    beforeEach ->
      room.robot.logger = sinon.spy()
      room.robot.logger.debug = sinon.spy()
      room.robot.logger.warning = sinon.spy()

    context 'with invalid payload', ->
      beforeEach (done) ->
        do nock.enableNetConnect
        options = {
          host: 'localhost',
          port: process.env.PORT,
          path: process.env.PAGERV2_ENDPOINT,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          }
        }
        data = querystring.stringify({ })
        req = http.request options, (@response) => done()
        req.write(data)
        req.end()

      it 'responds with status 422', ->
        expect(room.robot.logger.warning)
          .calledWith '[pagerv2] Invalid hook payload from 127.0.0.1'
        expect(@response.statusCode).to.equal 422

    context 'with invalid payload, but containing a messages object', ->
      beforeEach (done) ->
        do nock.enableNetConnect
        options = {
          host: 'localhost',
          port: process.env.PORT,
          path: process.env.PAGERV2_ENDPOINT,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          }
        }
        data = JSON.stringify({ messages: 'hahaha' })
        req = http.request options, (@response) => done()
        req.write(data)
        req.end()

      it 'responds with status 422', ->
        expect(room.robot.logger.warning)
          .calledWith '[pagerv2] Invalid hook payload from 127.0.0.1'
        expect(@response.statusCode).to.equal 422

    context 'with invalid type', ->
      beforeEach (done) ->
        do nock.enableNetConnect
        options = {
          host: 'localhost',
          port: process.env.PORT,
          path: process.env.PAGERV2_ENDPOINT,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          }
        }
        @msg = require('./fixtures/webhook_resolve.json')
        @msg.messages[0].type = 'plouf'
        data = JSON.stringify(@msg)
        req = http.request options, (@response) => done()
        req.write(data)
        req.end()

      it 'responds with status 422', ->
        expect(room.robot.logger.debug).calledWith @msg
        expect(room.robot.logger.warning)
          .calledWith '[pagerv2] Invalid hook payload type plouf from 127.0.0.1'
        expect(@response.statusCode).to.equal 422

    context 'with valid payload', ->
      beforeEach (done) ->
        do nock.enableNetConnect
        options = {
          host: 'localhost',
          port: process.env.PORT,
          path: process.env.PAGERV2_ENDPOINT,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          }
        }
        @msg = require('./fixtures/webhook_resolve.json')
        @msg.messages[0].type = 'incident.plouf'
        data = JSON.stringify(@msg)
        req = http.request options, (@response) => done()
        req.write(data)
        req.end()

      it 'responds with status 422', ->
        expect(room.robot.logger.debug).calledWith @msg
        expect(@response.statusCode).to.equal 200
