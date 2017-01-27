require('es6-promise').polyfill()

Helper = require 'hubot-test-helper'
helper = new Helper('../scripts/pagerv2_commands.coffee')
Hubot = require '../node_modules/hubot'

path   = require 'path'
nock   = require 'nock'
sinon  = require 'sinon'
expect = require('chai').use(require('sinon-chai')).expect

room = null

describe 'pagerv2_commands', ->

  hubotEmit = (e, data, tempo = 40) ->
    beforeEach (done) ->
      room.robot.emit e, data
      setTimeout (done), tempo
 
  hubotHear = (message, userName = 'momo', tempo = 40) ->
    beforeEach (done) ->
      room.user.say userName, message
      setTimeout (done), tempo

  hubot = (message, userName = 'momo') ->
    hubotHear "@hubot #{message}", userName

  hubotResponse = (i = 1) ->
    room.messages[i]?[1]

  hubotResponseCount = ->
    room.messages?.length - 1

  say = (command, cb) ->
    context "\"#{command}\"", ->
      hubot command
      cb()

  only = (command, cb) ->
    context.only "\"#{command}\"", ->
      hubot command
      cb()

  beforeEach ->
    do nock.enableNetConnect

    process.env.PAGERV2_API_KEY = 'xxx'
    process.env.PAGERV2_SCHEDULE_ID = '42'
    room = helper.createRoom { httpd: false }
    room.robot.brain.userForId 'user', {
      name: 'user'
    }
    room.robot.brain.userForId 'user_with_email', {
      name: 'user_with_email',
      email_address: 'user@example.com'
    }
    # room.robot.brain.data.pagerv2 = {
    #   users: {
    #     momo: {
    #       id: 'momo',
    #       name: 'momo',
    #       email: 'momo@example.com',
    #       pdid: 'AAAAA42'
    #     }
    #   }
    # }

    room.receive = (userName, message) ->
      new Promise (resolve) =>
        @messages.push [userName, message]
        user = { name: userName, id: userName }
        @robot.receive(new Hubot.TextMessage(user, message), resolve)

  afterEach ->
    delete process.env.PAGERV2_API_KEY
    delete process.env.PAGERV2_SCHEDULE_ID

  # ------------------------------------------------------------------------------------------------
  say 'pd version', ->
    it 'replies version number', ->
      expect(hubotResponse()).to.match /hubot-pager-v2 is version [0-9]+\.[0-9]+\.[0-9]+/

  # ------------------------------------------------------------------------------------------------
  describe '".pd me"', ->
    context 'with a first time user,', ->
      say 'pd me', ->
        it 'asks to declare email', ->
          expect(hubotResponse())
          .to.eql "Sorry, I can't figure out your email address :( " +
                  'Can you tell me with `.pd me as <email>`?'

    context 'with a user that has unknown email,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/users')
        .reply 200, require('./fixtures/users_list-nomatch.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd me', ->
        it 'asks to declare email', ->
          expect(hubotResponse())
          .to.eql "Sorry, I can't figure out your email address :( " +
                  'Can you tell me with `.pd me as <email>`?'

    context 'with a user that has a known email,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = {
          users: {
            momo: {
              id: 'momo',
              name: 'momo',
              email: 'momo@example.com'
            }
          }
        }
        nock('https://api.pagerduty.com')
        .get('/users')
        .reply 200, require('./fixtures/users_list-match.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd me', ->
        it 'gets user information from PD', ->
          expect(hubotResponse())
          .to.eql 'Oh I know you, you are PXPGF42.'
        it 'records PDid in brain', ->
          expect(room.robot.brain.data.pagerv2.users['momo'].pdid)
          .to.eql 'PXPGF42'

    context 'with a user that already has a pdid,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = {
          users: {
            momo: {
              id: 'momo',
              name: 'momo',
              email: 'momo@example.com',
              pdid: 'AAAAA42'
            }
          }
        }
      afterEach ->
        room.robot.brain.data.pagerv2 = { }

      say 'pd me', ->
        it 'returns information from brain', ->
          expect(hubotResponse())
          .to.eql 'Oh I know you, you are AAAAA42.'

  # ------------------------------------------------------------------------------------------------
  describe '".pd me as <email>"', ->
    context 'with an unknown email,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/users')
        .reply 200, require('./fixtures/users_list-nomatch.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd me as toto@example.com', ->
        it 'asks to declare email', ->
          expect(hubotResponse())
          .to.eql 'Sorry, I cannot find toto@example.com'

    context 'with a known email,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/users')
        .reply 200, require('./fixtures/users_list-match.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd me as toto@example.com', ->
        it 'returns information from pager', ->
          expect(hubotResponse())
          .to.eql 'Ok now I know you are PXPGF42.'

  # ------------------------------------------------------------------------------------------------
  describe '".pd <user> as <email>"', ->
    context 'with an unknown email,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/users')
        .reply 200, require('./fixtures/users_list-nomatch.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd toto as toto@example.com', ->
        it 'asks to declare email', ->
          expect(hubotResponse())
          .to.eql 'Sorry, I cannot find toto@example.com'

    context 'with a known email,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/users')
        .reply 200, require('./fixtures/users_list-match.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd toto as toto@example.com', ->
        it 'returns information from pager', ->
          expect(hubotResponse())
          .to.eql 'Ok now I know toto is PXPGF42.'

  # ------------------------------------------------------------------------------------------------
  describe '".pd oncall"', ->
    context 'when everything goes right,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/schedules/42')
        .reply 200, require('./fixtures/schedule_get-ok.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd oncall', ->
        it 'returns name of who is on call', ->
          expect(hubotResponse())
          .to.eql 'Regina Phalange is on call until Tuesday 22:00 (utc).'

  # ------------------------------------------------------------------------------------------------
  describe '".pd 120000"', ->
    context 'when everything goes right,', ->
      say 'pd 120000', ->
        it 'warns that this duration does not make any sense', ->
          expect(hubotResponse())
          .to.eql 'Sorry you cannot set an override of more than 1 day.'

  describe '".pd 120"', ->
    context 'when everything goes right,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = {
          users: {
            momo: {
              id: 'momo',
              name: 'momo',
              email: 'momo@example.com',
              pdid: 'AAAAA42'
            }
          }
        }
        nock('https://api.pagerduty.com')
        .get('/schedules/42')
        .reply(200, require('./fixtures/schedule_get-ok.json'))
        .post('/schedules/42/overrides')
        .reply(200, require('./fixtures/override_create-ok.json'))
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd 120', ->
        it 'says override is done', ->
          expect(hubotResponse())
          .to.eql 'Rejoice Aurelio Rice! momo is now on call.'

  # ------------------------------------------------------------------------------------------------
  describe '".pd not me"', ->
    context 'when everything goes right,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = {
          users: {
            momo: {
              id: 'momo',
              name: 'momo',
              email: 'momo@example.com',
              pdid: 'PEYSGVF'
            }
          }
        }
        nock('https://api.pagerduty.com')
        .get('/schedules/42/overrides')
        .reply(200, require('./fixtures/override_get-ok.json'))
        .delete('/schedules/42/overrides/PQ47DCP')
        .reply(200, require('./fixtures/override_get-ok.json'))

      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd not me', ->
        it 'returns name of who is on call', ->
          expect(hubotResponse())
          .to.eql 'Ok, momo! Aurelio Rice override is cancelled.'

  # ------------------------------------------------------------------------------------------------
  describe '".pd incident 1234"', ->
    context 'when everything goes right,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = {
          users: {
            momo: {
              id: 'momo',
              name: 'momo',
              email: 'momo@example.com',
              pdid: 'PEYSGVF'
            }
          }
        }
        nock('https://api.pagerduty.com')
        .get('/incidents/1234')
        .reply(200, require('./fixtures/incident_get-ok.json'))

      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd incident 1234', ->
        it 'returns details on the incident', ->
          expect(hubotResponse())
          .to.eql 'PT4KHLK (resolved) The server is on fire.'

  # ------------------------------------------------------------------------------------------------
  describe '".pd sup"', ->
    context 'when everything goes right,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = {
          users: {
            momo: {
              id: 'momo',
              name: 'momo',
              email: 'momo@example.com',
              pdid: 'PEYSGVF'
            }
          }
        }
        nock('https://api.pagerduty.com')
        .get('/incidents')
        .reply(200, require('./fixtures/incident_list-ok.json'))

      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd sup', ->
        it 'returns details on the incident', ->
          expect(hubotResponse())
          .to.eql 'PT4KHLK (resolved) The server is on fire.'

  # ------------------------------------------------------------------------------------------------
  describe '".pd ack"', ->
    context 'when everything goes right,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = {
          users: {
            momo: {
              id: 'momo',
              name: 'momo',
              email: 'momo@example.com',
              pdid: 'PEYSGVF'
            }
          }
        }
        nock('https://api.pagerduty.com')
        .get('/incidents')
        .reply(200, require('./fixtures/incident_list-ok.json'))
        .put('/incidents')
        .reply(200, require('./fixtures/incident_manage-ok.json'))

      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd ack', ->
        it 'returns details on the incident', ->
          expect(hubotResponse())
          .to.eql 'Incident PT4KHLK acknowledged.'

  # ------------------------------------------------------------------------------------------------
  describe '".pd ack PT4KHLK"', ->
    context 'when everything goes right,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = {
          users: {
            momo: {
              id: 'momo',
              name: 'momo',
              email: 'momo@example.com',
              pdid: 'PEYSGVF'
            }
          }
        }
        nock('https://api.pagerduty.com')
        .put('/incidents')
        .reply(200, require('./fixtures/incident_manage-ok.json'))

      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd ack PT4KHLK', ->
        it 'returns details on the incident', ->
          expect(hubotResponse())
          .to.eql 'Incident PT4KHLK acknowledged.'

  # ------------------------------------------------------------------------------------------------
  describe '".pd res"', ->
    context 'when everything goes right,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = {
          users: {
            momo: {
              id: 'momo',
              name: 'momo',
              email: 'momo@example.com',
              pdid: 'PEYSGVF'
            }
          }
        }
        nock('https://api.pagerduty.com')
        .get('/incidents')
        .reply(200, require('./fixtures/incident_list-ok.json'))
        .put('/incidents')
        .reply(200, require('./fixtures/incident_manage-ok.json'))

      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd ack', ->
        it 'returns details on the incident', ->
          expect(hubotResponse())
          .to.eql 'Incident PT4KHLK acknowledged.'
