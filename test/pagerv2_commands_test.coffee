require('es6-promise').polyfill()

Helper = require 'hubot-test-helper'
helper = new Helper('../scripts/pagerv2_commands.coffee')
Hubot = require '../node_modules/hubot'

path     = require 'path'
nock     = require 'nock'
sinon    = require 'sinon'
moment   = require 'moment'
expect   = require('chai').use(require('sinon-chai')).expect

room = null

describe 'pagerv2_commands', ->

  hubotEmit = (e, data, tempo = 50) ->
    beforeEach (done) ->
      room.robot.emit e, data
      setTimeout (done), tempo
 
  hubotHear = (message, userName = 'momo', tempo = 50) ->
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
    process.env.PAGERV2_SERVICES = 'My Application Service,Other Service'
    process.env.PAGERV2_LOG_PATH = 'test/'
    process.env.PAGERV2_CUSTOM_ACTION_FILE = './test/fixtures/custom_action.json'
    room = helper.createRoom { httpd: false }
    room.robot.brain.userForId 'user', {
      name: 'user'
    }
    room.robot.brain.userForId 'user_with_email', {
      name: 'user_with_email',
      email_address: 'user@example.com'
    }
    moment.now = ->
      +new Date('February 2, 2017 02:02:00 UTC')

    room.receive = (userName, message) ->
      new Promise (resolve) =>
        @messages.push [userName, message]
        user = { name: userName, id: userName }
        @robot.receive(new Hubot.TextMessage(user, message), resolve)

  afterEach ->
    delete process.env.PAGERV2_API_KEY
    delete process.env.PAGERV2_SCHEDULE_ID
    delete process.env.PAGERV2_SERVICES

  # ------------------------------------------------------------------------------------------------
  say 'pager version', ->
    it 'replies version number', ->
      expect(hubotResponse()).to.match /hubot-pager-v2 is version [0-9]+\.[0-9]+\.[0-9]+/

  # ------------------------------------------------------------------------------------------------
  describe '".pager me"', ->
    context 'with a first time user,', ->
      say 'pager me', ->
        it 'asks to declare email', ->
          expect(hubotResponse())
          .to.eql "Sorry, I can't figure out your email address :( " +
                  'Can you tell me with `.pager me as <email>`?'

    context 'with a user that has unknown email,', ->
      beforeEach ->
        nock('https://api.pagerduty.com')
        .get('/users')
        .reply 200, require('./fixtures/users_list-nomatch.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager me', ->
        it 'asks to declare email', ->
          expect(hubotResponse())
          .to.eql "Sorry, I can't figure out your email address :( " +
                  'Can you tell me with `.pager me as <email>`?'
 
    context 'with a faulty user input', ->
      beforeEach ->
        nock('https://api.pagerduty.com')
        .get('/users')
        .reply 200, require('./fixtures/users_list-nomatch.json')
        room.receive = (userName, message) ->
          new Promise (resolve) =>
            @messages.push [userName, message]
            user = { name: userName }
            @robot.receive(new Hubot.TextMessage(user, message), resolve)
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager me', ->
        it 'asks to declare email', ->
          expect(hubotResponse())
          .to.eql "Sorry, I can't figure out your email address :( " +
                  'Can you tell me with `.pager me as <email>`?'


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
        .query({
          query: 'momo@example.com'
        })
        .reply 200, require('./fixtures/users_list-match.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager me', ->
        it 'gets user information from pager', ->
          expect(hubotResponse())
          .to.eql 'Oh I know you, you are PXPGF42.'
        it 'records pagerid in brain', ->
          expect(room.robot.brain.data.pagerv2.users['momo'].pagerid)
          .to.eql 'PXPGF42'

    context 'with a user that already has a pagerid,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = {
          users: {
            momo: {
              id: 'momo',
              name: 'momo',
              email: 'momo@example.com',
              pagerid: 'AAAAA42'
            }
          }
        }
      afterEach ->
        room.robot.brain.data.pagerv2 = { }

      say 'pager me', ->
        it 'returns information from brain', ->
          expect(hubotResponse())
          .to.eql 'Oh I know you, you are AAAAA42.'

# ------------------------------------------------------------------------------------------------
  describe '".pager who is momo"', ->
    context 'with a first time user,', ->
      say 'pager who is momo', ->
        it 'asks to declare email', ->
          expect(hubotResponse())
          .to.eql "Sorry, I can't figure out your email address :( " +
                  'Can you tell me with `.pager me as <email>`?'

    context 'with a user that has unknown email,', ->
      beforeEach ->
        nock('https://api.pagerduty.com')
        .get('/users')
        .reply 200, require('./fixtures/users_list-nomatch.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager who is momo', ->
        it 'asks to declare email', ->
          expect(hubotResponse())
          .to.eql "Sorry, I can't figure out your email address :( " +
                  'Can you tell me with `.pager me as <email>`?'

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
        .query({
          query: 'momo@example.com'
        })
        .reply 200, require('./fixtures/users_list-match.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager who is momo', ->
        it 'gets user information from pager', ->
          expect(hubotResponse())
          .to.eql 'Oh I know momo, momo is PXPGF42.'
        it 'records pagerid in brain', ->
          expect(room.robot.brain.data.pagerv2.users['momo'].pagerid)
          .to.eql 'PXPGF42'

    context 'with a user that already has a pagerid,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = {
          users: {
            momo: {
              id: 'momo',
              name: 'momo',
              email: 'momo@example.com',
              pagerid: 'AAAAA42'
            }
          }
        }
      afterEach ->
        room.robot.brain.data.pagerv2 = { }

      say 'pager who is momo', ->
        it 'returns information from brain', ->
          expect(hubotResponse())
          .to.eql 'Oh I know momo, momo is AAAAA42.'

  #

  # ------------------------------------------------------------------------------------------------
  describe '".pager me as <email>"', ->
    context 'with an unknown email,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/users')
        .query({
          query: 'toto@example.com'
        })
        .reply 200, require('./fixtures/users_list-nomatch.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager me as toto@example.com', ->
        it 'asks to declare email', ->
          expect(hubotResponse())
          .to.eql 'Sorry, I cannot find toto@example.com'

    context 'with a known email,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/users')
        .query({
          query: 'toto@example.com'
        })
        .reply 200, require('./fixtures/users_list-match.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager me as toto@example.com', ->
        it 'returns information from pager', ->
          expect(hubotResponse()).to.eql 'Ok now I know you are PXPGF42.'
          expect(room.robot.brain.data.pagerv2.users.momo.email).to.eql 'toto@example.com'
          expect(room.robot.brain.data.pagerv2.users.momo.pagerid).to.eql 'PXPGF42'

    context 'but an http error occurs,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/users')
        .query({
          query: 'toto@example.com'
        })
        .replyWithError({ message: 'server error', code: 429 })
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager me as toto@example.com', ->
        it 'returns information about the error', ->
          expect(hubotResponse()).to.eql '429 server error'

    context 'but pagerduty api key is not set,', ->
      beforeEach ->
        delete process.env.PAGERV2_API_KEY
        room.robot.brain.data.pagerv2 = { users: { } }

      afterEach ->
        room.robot.brain.data.pagerv2 = { }

      say 'pager me as toto@example.com', ->
        it 'returns an error message', ->
          expect(hubotResponse()).to.eql 'PAGERV2_API_KEY is not set in your environment.'

  # ------------------------------------------------------------------------------------------------
  describe '".pager <user> as <email>"', ->
    context 'with an unknown email,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/users')
        .query({
          query: 'toto@example.com'
        })
        .reply 200, require('./fixtures/users_list-nomatch.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager toto as toto@example.com', ->
        it 'asks to declare email', ->
          expect(hubotResponse())
          .to.eql 'Sorry, I cannot find toto@example.com'

    context 'with a known email,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/users')
        .query({
          query: 'toto@example.com'
        })
        .reply 200, require('./fixtures/users_list-match.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager toto as toto@example.com', ->
        it 'returns information from pager', ->
          expect(hubotResponse())
          .to.eql 'Ok now I know toto is PXPGF42.'
    
    context 'by an unauthorized user,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/users')
        .query({
          query: 'toto@example.com'
        })
        .reply 200, require('./fixtures/users_list-match.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager toto as toto@example.com', ->
        it 'returns information from pager', ->
          expect(hubotResponse())
          .to.eql 'Ok now I know toto is PXPGF42.'


  # ------------------------------------------------------------------------------------------------
  describe '".pager oncall <msg>"', ->
    context 'when something goes wrong,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 42 ],
          earliest: true
        })
        .reply 503, { error: { code: 503, message: "it's all broken!" } }
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager oncall doing stuff', ->
        it 'returns the error message', ->
          expect(hubotResponse())
          .to.eql "503 it's all broken!"

    context 'when in a different channel,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 42 ],
          earliest: true
        })
        .reply 200, require('./fixtures/oncall_list-ok.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager oncall doing stuff', ->
        it 'returns name of who is on call', ->
          expect(hubotResponse())
          .to.eql 'Ok, I\'ll notify Tim Wright.'
    
    context 'when in a different channel', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        room.receive = (userName, message) ->
          new Promise (resolve) =>
            @messages.push [userName, message]
            user = { name: userName }
            textMessage = new Hubot.TextMessage(user, message)
            textMessage.room = 'somewhereelse'
            @robot.receive(textMessage, resolve)

        nock('https://api.pagerduty.com')
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 42 ],
          earliest: true
        })
        .reply 200, require('./fixtures/oncall_list-ok.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager oncall doing stuff somewhere else', ->
        it 'send a message to the right channel', ->
          expect(hubotResponse())
              .to.eql 'Tim Wright: doing stuff somewhere else (from momo on somewhereelse)'
    context 'when in a query', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        room.receive = (userName, message) ->
          new Promise (resolve) =>
            @messages.push [userName, message]
            user = { name: userName }
            textMessage = new Hubot.TextMessage(user, message)
            textMessage.room = false
            @robot.receive(textMessage, resolve)

        nock('https://api.pagerduty.com')
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 42 ],
          earliest: true
        })
        .reply 200, require('./fixtures/oncall_list-ok.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager oncall doing stuff somewhere else', ->
        it 'send a message to the right channel', ->
          expect(hubotResponse())
              .to.eql 'Tim Wright: doing stuff somewhere else (from momo)'



  # ------------------------------------------------------------------------------------------------
  describe '".pager oncall"', ->
    context 'when something goes wrong,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 42 ],
          earliest: true
        })
        .reply 503, { error: { code: 503, message: "it's all broken!" } }
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager oncall', ->
        it 'returns the error message', ->
          expect(hubotResponse())
          .to.eql "503 it's all broken!"

    context 'when everything goes right,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 42 ],
          earliest: true
        })
        .reply 200, require('./fixtures/oncall_list-ok.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager oncall', ->
        it 'returns name of who is on call', ->
          expect(hubotResponse())
          .to.eql 'Tim Wright is on call until Saturday 20:28 (utc).'

    context 'when it is same day,', ->
      beforeEach ->
        payload = require('./fixtures/oncall_list-ok.json')
        @end_time = moment().utc().add(5, 'minutes')
        payload.oncalls[0].start = moment().utc().subtract(5, 'minutes').format()
        payload.oncalls[0].end = @end_time.format()
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 42 ],
          earliest: true
        })
        .reply 200, payload
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager oncall', ->
        it 'returns name of who is on call', ->
          expect(hubotResponse())
          .to.eql "Tim Wright is on call until #{@end_time.format('HH:mm')} (utc)."

  # ------------------------------------------------------------------------------------------------
  describe '".pager schedule"', ->
    context 'when something goes wrong,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        room.robot.brain.data.pagerv2.schedules = { }
        nock('https://api.pagerduty.com')
        .get('/schedules')
        .reply 503, { error: { code: 503, message: "it's all broken!" } }
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager schedule a', ->
        it 'returns the error message', ->
          expect(hubotResponse())
          .to.eql "503 it's all broken!"

    context 'when somebody is oncall', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        room.robot.brain.data.pagerv2.schedules = { }
        payload = require('./fixtures/oncall_list-ok.json')
        payload.oncalls[0].start = moment().utc().subtract(5,'minutes').format()
        @end_date = moment.utc().add(1,'days')
        payload.oncalls[0].end = @end_date.format()
        @end_date_format = @end_date.format('dddd HH:mm')
        nock('https://api.pagerduty.com')
        .get('/schedules')
        .reply(200, require('./fixtures/schedules_list-ok.json'))
        .get('/schedules/PI7DH85')
        .reply(200, require('./fixtures/schedule_get-ok.json'))
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 'PI7DH85' ],
          earliest: true
        })
        .reply 200, payload
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager schedule daily_rotation', ->
        it 'when it\'s not the same day', ->
          expect(hubotResponse())
          .to.eql "Tim Wright is on call until #{@end_date_format} (utc) in Daily Engineering Rotation."

    context 'when nobody is oncall', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        room.robot.brain.data.pagerv2.schedules = { }
        payload = require('./fixtures/oncall_list-ok.json')
        nock('https://api.pagerduty.com')
        .get('/schedules')
        .reply(200, require('./fixtures/schedules_list-ok.json'))
        .get('/schedules/PI7DH85')
        .reply(200, require('./fixtures/schedule_get-ok.json'))
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 'PI7DH85' ],
          earliest: true
        })
        .reply(200, { 'oncalls': [] })
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager schedule daily_rotation', ->
        it 'when it\'s not the same day', ->
          expect(hubotResponse())
          .to.eql "Nobody is oncall at the moment on the schedule Daily Engineering Rotation : Rotation schedule for engineering"


    context 'when someone is on call the same day,', ->
      beforeEach ->
        payload = require('./fixtures/oncall_list-ok.json')
        @end_time = moment().utc().add(5, 'minutes')
        payload.oncalls[0].start = moment().utc().subtract(5, 'minutes').format()
        payload.oncalls[0].end = @end_time.format()
        room.robot.brain.data.pagerv2 = { users: { } }
        room.robot.brain.data.pagerv2.schedules = { }
        nock('https://api.pagerduty.com')
        .get('/schedules')
        .reply( 200, require('./fixtures/schedules_list-ok.json'))
        .get('/schedules/PI7DH85')
        .reply(200, require('./fixtures/schedule_get-ok.json'))
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 'PI7DH85' ],
          earliest: true
        })
        .reply 200, payload
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager schedule daily_rotation', ->
        it 'returns name of who is on call', ->
          expect(hubotResponse())
          .to.eql "Tim Wright is on call until #{@end_time.format('HH:mm')} (utc) in Daily Engineering Rotation."



    context 'when there is no matching schedule', ->
      beforeEach ->
        payload = require('./fixtures/oncall_list-ok.json')
        @end_time = moment().utc().add(5, 'minutes')
        payload.oncalls[0].start = moment().utc().subtract(5, 'minutes').format()
        payload.oncalls[0].end = @end_time.format()
        room.robot.brain.data.pagerv2 = { users: { } }
        room.robot.brain.data.pagerv2.schedules = { }
        nock('https://api.pagerduty.com')
        .get('/schedules')
        .reply( 200, require('./fixtures/schedules_list-ok.json'))
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager schedule no_matching', ->
        it 'returns name of who is on call', ->
          expect(hubotResponse())
          .to.eql "Error: no matching schedule found"


    context 'when there is an error with schedules', ->
      beforeEach ->
        payload = require('./fixtures/oncall_list-ok.json')
        @end_time = moment().utc().add(5, 'minutes')
        payload.oncalls[0].start = moment().utc().subtract(5, 'minutes').format()
        payload.oncalls[0].end = @end_time.format()
        room.robot.brain.data.pagerv2 = { users: { } }
        room.robot.brain.data.pagerv2.schedules = {'daily_rotation':'PI7DH85' }
        nock('https://api.pagerduty.com')
        .get('/schedules/PI7DH85')
        .reply(200, require('./fixtures/schedule_get-ok.json'))
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 'PI7DH85' ],
          earliest: true
        })
        .reply(500, 'internal server error')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()
      say 'pager schedule daily_rotation', ->
        it 'returns name of who is on call', ->
          expect(hubotResponse())
          .to.eql 'Unable to get oncall : Unable to read request output'



  # ------------------------------------------------------------------------------------------------
  describe '".pager next oncall"', ->
    context 'when something goes wrong,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 42 ],
          earliest: true
        })
        .reply 503, { error: { code: 503, message: "it's all broken!" } }
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager next oncall', ->
        it 'returns the error message', ->
          expect(hubotResponse())
          .to.eql "503 it's all broken!"

    context 'when everything goes right,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 42 ],
          earliest: true
        })
        .reply(200, require('./fixtures/oncall_list-ok.json'))
        .filteringPath( (path) ->
          path.replace /(since|until)=[^&]*/g, '$1=x'
        )
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 42 ],
          earliest: true,
          since: 'x',
          until: 'x'
        })
        .reply 200, require('./fixtures/oncall_list_next-ok.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager next oncall', ->
        it 'returns name of who is on call', ->
          expect(hubotResponse())
          .to.eql 'Bea Blala will be next on call on Saturday 20:28 until Saturday 23:28 (utc).'

    context 'when it is same day,', ->
      beforeEach ->
        payload1 = require('./fixtures/oncall_list-ok.json')
        payload1.oncalls[0].start = moment().utc().subtract(5, 'minutes').format()
        payload1.oncalls[0].end = moment().utc().add(5, 'minutes')

        payload2 = require('./fixtures/oncall_list_next-ok.json')
        @start_time = moment().utc().add(5, 'minutes')
        @end_time   = moment().utc().add(10, 'minutes')
        payload2.oncalls[0].start = @start_time.format()
        payload2.oncalls[0].end = @end_time.format()

        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 42 ],
          earliest: true
        })
        .reply(200, payload1)
        .get('/oncalls')
        .query({
          time_zone: 'UTC',
          schedule_ids: [ 42 ],
          earliest: true,
          since: moment(@start_time).utc().add(2, 'minute').format(),
          until: moment(@start_time).utc().add(3, 'minute').format()
        })
        .reply(200, payload2)

      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager next oncall', ->
        it 'returns name of who is on call', ->
          expect(hubotResponse())
          .to.eql "Bea Blala will be next on call at #{@start_time.format('HH:mm')} " +
                  "until #{@end_time.format('HH:mm')} (utc)."

  # ----------------------------------------------------------------------------------------------
  describe '".pager assign all to me"', ->
    context 'when the recorded email is not known by pagerduty,', ->
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
        .query({
          query: 'momo@example.com'
        })
        .reply(200, require('./fixtures/users_list-nomatch.json'))
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager assign all to me', ->
        it 'returns the error message', ->
          expect(hubotResponse())
          .to.eql 'Sorry, I cannot find momo@example.com'
    
    context 'when the user mail is faulty,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = {
          users: {
            momo: {
              id: 'momo',
              name: 'momo',
            }
          }
        }
        nock('https://api.pagerduty.com')
        .get('/users')
        .query({
          query: 'momo@example.com'
        })
        .reply(200, require('./fixtures/users_list-nomatch.json'))
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager assign all to me', ->
        it 'returns the error message', ->
          expect(hubotResponse())
          .to.eql "Sorry, I can't figure out your email address :( " +
          'Can you tell me with `.pager me as <email>`?'
     
    context 'when the user is faulty,', ->
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
        .query({
          query: 'momo@example.com'
        })
        .reply(200, require('./fixtures/users_list-nomatch.json'))
        room.receive = (userName, message) ->
          new Promise (resolve) =>
            @messages.push [userName, message]
            user = { name: userName }
            @robot.receive(new Hubot.TextMessage(user, message), resolve)
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pager assign all to me', ->
        it 'returns the error message', ->
          expect(hubotResponse())
          .to.eql 'Sorry, I cannot find momo@example.com'
     

  # ================================================================================================
  context 'caller is known', ->
    beforeEach ->
      room.robot.brain.data.pagerv2.users = {
        momo: {
          id: 'momo',
          name: 'momo',
          email: 'momo@example.com',
          pagerid: 'PEYSGVF'
        }
      }
      room.robot.brain.data.pagerv2.services = { }

    afterEach ->
      room.robot.brain.data.pagerv2 = { }

    # ----------------------------------------------------------------------------------------------
    describe '".pager 120000"', ->
      context 'when everything goes right,', ->
        say 'pager 120000', ->
          it 'warns that this duration does not make any sense', ->
            expect(hubotResponse())
            .to.eql 'Sorry you cannot set an override of more than 1 day.'

    describe '".pager 120"', ->
      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/oncalls')
          .query({
            time_zone: 'UTC',
            schedule_ids: [ 42 ],
            earliest: true
          })
          .reply(200, require('./fixtures/oncall_list-ok.json'))
          .post('/schedules/42/overrides')
          .reply(200, require('./fixtures/override_create-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager 120', ->
          it 'says override is done', ->
            expect(hubotResponse())
            .to.eql 'Rejoice Tim Wright! momo is now on call.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager me next"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/oncalls')
          .query({
            time_zone: 'UTC',
            schedule_ids: [ 42 ],
            earliest: true
          })
          .reply(200, require('./fixtures/oncall_list-ok.json'))
          .filteringPath( (path) ->
            path.replace /(since|until)=[^&]*/g, '$1=x'
          )
          .get('/oncalls')
          .query({
            time_zone: 'UTC',
            schedule_ids: [ 42 ],
            earliest: true,
            since: 'x',
            until: 'x'
          })
          .reply(200, require('./fixtures/oncall_list_next-ok.json'))
          .post('/schedules/42/overrides')
          .reply(503, { error: { code: 503, message: "it's all broken!" } })
        afterEach ->
          nock.cleanAll()
        
        say 'pager me next ', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when someone override itself', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .filteringPath( (path) ->
            path.replace /(since|until)=[^&]*/g, '$1=x'
          )
          .get('/oncalls')
          .query({
            time_zone: 'UTC',
            schedule_ids: [ 42 ],
            earliest: true
          })
          .reply(200, require('./fixtures/oncall_list-ok.json'))
          .filteringPath( (path) ->
            path.replace /(since|until)=[^&]*/g, '$1=x'
          )
          .get('/oncalls')
          .query({
            time_zone: 'UTC',
            schedule_ids: [ 42 ],
            earliest: true,
            since: 'x',
            until: 'x'
          })
          .reply(200, require('./fixtures/oncall_list-next-dup.json'))
        afterEach ->
          nock.cleanAll()
         
        say 'pager me next ', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "Sorry, you can't override yourself"
    
      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/oncalls')
          .query({
            time_zone: 'UTC',
            schedule_ids: [ 42 ],
            earliest: true
          })
          .reply(200, require('./fixtures/oncall_list-ok.json'))
          .filteringPath( (path) ->
            path.replace /(since|until)=[^&]*/g, '$1=x'
          )
          .get('/oncalls')
          .query({
            time_zone: 'UTC',
            schedule_ids: [ 42 ],
            earliest: true,
            since: 'x',
            until: 'x'
          })
          .reply(200, require('./fixtures/oncall_list_next-ok.json'))
          .post('/schedules/42/overrides')
          .reply(200, require('./fixtures/override_create-ok.json'))
        afterEach ->
          nock.cleanAll()
        say 'pager me next ', ->
          it 'says override is done', ->
            expect(hubotResponse())
            .to.eql 'Rejoice Bea Blala! momo will be on call ' +
                    'from Thursday 02:07 to Thursday 02:12 (utc)'

        
    # ----------------------------------------------------------------------------------------------
    describe '".pager not me"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .filteringPath( (path) ->
            path.replace /(since|until)=[^&]*/g, '$1=x'
          )
          .get('/schedules/42/overrides')
          .query({
            since: 'x',
            until: 'x',
            editable: true,
            overflow: true
          })
          .reply(200, require('./fixtures/override_get-ok.json'))
          .delete('/schedules/42/overrides/PQ47DCP')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager not me', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when there is no override,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
            .filteringPath( (path) ->
              path.replace /(since|until)=[^&]*/g, '$1=x'
          )
          .get('/schedules/42/overrides')
          .query({
            since: 'x',
            until: 'x',
            editable: true,
            overflow: true
          })
          .reply(200, require('./fixtures/override_get-empty.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager not me', ->
          it 'returns name of who is on call', ->
            expect(hubotResponse())
            .to.eql "Sorry there is no overrides for 'you' at the moment."
      context 'when there is no data returned,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
            .filteringPath( (path) ->
              path.replace /(since|until)=[^&]*/g, '$1=x'
          )
          .get('/schedules/42/overrides')
          .query({
            since: 'x',
            until: 'x',
            editable: true,
            overflow: true
          })
          .reply(200, '')
        afterEach ->
          nock.cleanAll()

        say 'pager not me', ->
          it 'returns name of who is on call', ->
            expect(hubotResponse())
            .to.eql "Sorry there is no overrides for 'you' at the moment."


      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .filteringPath( (path) ->
            path.replace /(since|until)=[^&]*/g, '$1=x'
          )
          .get('/schedules/42/overrides')
          .query({
            since: 'x',
            until: 'x',
            editable: true,
            overflow: true
          })
          .reply(200, require('./fixtures/override_get-ok.json'))
          .delete('/schedules/42/overrides/PQ47DCP')
          .reply(200, require('./fixtures/override_get-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager not me', ->
          it 'returns name of who is on call', ->
            expect(hubotResponse())
            .to.eql 'Ok, momo! your override is cancelled.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager me now"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/oncalls')
          .query({
            time_zone: 'UTC',
            schedule_ids: [ 42 ],
            earliest: true
          })
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager me now', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"
        

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/oncalls')
          .query({
            time_zone: 'UTC',
            schedule_ids: [ 42 ],
            earliest: true
          })
          .reply(200, require('./fixtures/oncall_list-ok.json'))
          .post('/schedules/42/overrides')
          .reply(200, require('./fixtures/override_create-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager me now', ->
          it 'returns name of who is on call', ->
            expect(hubotResponse())
            .to.eql 'Rejoice Tim Wright! momo is now on call.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager incident 1234"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          room.robot.brain.data.pagerv2 = { users: { } }
          nock('https://api.pagerduty.com')
          .get('/incidents/1234')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager incident 1234', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents/1234')
          .reply(200, require('./fixtures/incident_get-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager incident 1234', ->
          it 'returns details on the incident', ->
            expect(hubotResponse())
            .to.eql '[My Mail Service] PT4KHLK - The server is on fire. - ' +
                    'resolved (Earline Greenholt)'

    # ----------------------------------------------------------------------------------------------
    describe '".pager sup"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          room.robot.brain.data.pagerv2 = { users: { } }
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .query({
            time_zone: 'UTC',
            urgencies: [
              'high'
            ],
            sort_by: 'created_at',
            date_range: 'all',
            statuses: [
              'triggered',
              'acknowledged'
            ],
            limit: 100,
            total: 'true'
          })
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager sup', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'and there are no incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              date_range: 'all',
              statuses: [
                'triggered',
                'acknowledged'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list-empty.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager sup', ->
            it 'returns list of incidents', ->
              expect(hubotResponse())
              .to.eql 'There are no open incidents for now.'

        context 'and there are incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              date_range: 'all',
              statuses: [
                'triggered',
                'acknowledged'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager sup', ->
            it 'returns list of incidents', ->
              expect(hubotResponse())
              .to.eql '[My Mail Service] PT4KHLK - The server is on fire. - ' +
                      'resolved (Earline Greenholt)'

        context 'and we want incidents for the past 2 hours', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              since: '2017-02-02T00:02:00Z',
              until: '2017-02-02T02:02:00Z',
              statuses: [
                'triggered',
                'acknowledged',
                'resolved'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager sup 2', ->
            it 'returns list of incidents', ->
              expect(hubotResponse())
              .to.eql '[My Mail Service] PT4KHLK - The server is on fire. - ' +
                      'resolved (Earline Greenholt)'

        context 'and we want incidents since 8 hours ago for 4 hours', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              since: '2017-02-01T18:02:00Z',
              until: '2017-02-01T22:02:00Z',
              statuses: [
                'triggered',
                'acknowledged',
                'resolved'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager sup 8 4', ->
            it 'returns list of incidents', ->
              expect(hubotResponse())
              .to.eql '[My Mail Service] PT4KHLK - The server is on fire. - ' +
                      'resolved (Earline Greenholt)'
         
        context 'and there more than 100 incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              since: '2017-02-01T18:02:00Z',
              until: '2017-02-01T22:02:00Z',
              statuses: [
                'triggered',
                'acknowledged',
                'resolved'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_biglist-ok.json'))
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              since: '2017-02-01T18:02:00Z',
              until: '2017-02-01T22:02:00Z',
              statuses: [
                'triggered',
                'acknowledged',
                'resolved'
              ],
              limit: 100,
              offset: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list-ok.json'))
          
          afterEach ->
            nock.cleanAll()

          say 'pager sup 8 4', ->
            it 'returns list of incidents', ->
              expect(hubotResponse())
              .to.eql '[My Mail Service] PT4KHLK - The server is on fire. - ' +
                      'resolved (Earline Greenholt)'
    # ----------------------------------------------------------------------------------------------
    describe '".pager ack"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .query({
            time_zone: 'UTC',
            urgencies: [
              'high'
            ],
            sort_by: 'created_at',
            date_range: 'all',
            statuses: [
              'triggered'
            ],
            limit: 100,
            total: 'true'
          })
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager ack', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              date_range: 'all',
              statuses: [
                'triggered'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list-ok.json'))
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager ack', ->
            it 'says incident was acknowledged', ->
              expect(hubotResponse()).to.eql 'Incident PT4KHLK acknowledged.'

        context 'with multiple incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              date_range: 'all',
              statuses: [
                'triggered'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list_multi-ok.json'))
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage_multi-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager ack', ->
            it 'says incident was acknowledged', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 acknowledged.'

      context 'when there are no incidents,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .query({
            time_zone: 'UTC',
            urgencies: [
              'high'
            ],
            sort_by: 'created_at',
            date_range: 'all',
            statuses: [
              'triggered'
            ],
            limit: 100,
            total: 'true'
          })
          .reply(200, require('./fixtures/incident_list-empty.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager ack', ->
          it 'says there is no incidents', ->
            expect(hubotResponse())
            .to.eql 'There is no triggered incidents at the moment.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager ack PT4KHLK"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .put('/incidents')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager ack PT4KHLK', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager ack PT4KHLK', ->
            it 'says incident was acknowledged', ->
              expect(hubotResponse())
              .to.eql 'Incident PT4KHLK acknowledged.'

        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage_multi-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager ack PT4KHLK,1234567', ->
            it 'says incidents were acknowledged', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 acknowledged.'

          say 'pager ack PT4KHLK, 1234567', ->
            it 'says incidents were acknowledged', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 acknowledged.'

          say 'pager ack PT4KHLK 1234567', ->
            it 'says incidents were acknowledged', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 acknowledged.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager res"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .query({
            time_zone: 'UTC',
            urgencies: [
              'high'
            ],
            sort_by: 'created_at',
            date_range: 'all',
            statuses: [
              'acknowledged'
            ],
            limit: 100,
            total: 'true'
          })
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager res', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              date_range: 'all',
              statuses: [
                'acknowledged'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list-ok.json'))
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage-ok.json'))

          afterEach ->
            nock.cleanAll()

          say 'pager res', ->
            it 'says incident was resolved', ->
              expect(hubotResponse())
              .to.eql 'Incident PT4KHLK resolved.'

        context 'with many incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              date_range: 'all',
              statuses: [
                'acknowledged'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list_multi-ok.json'))
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage_multi-ok.json'))

          afterEach ->
            nock.cleanAll()

          say 'pager res', ->
            it 'says incident was resolved', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 resolved.'

      context 'when there are no incidents,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .query({
            time_zone: 'UTC',
            urgencies: [
              'high'
            ],
            sort_by: 'created_at',
            date_range: 'all',
            statuses: [
              'acknowledged'
            ],
            limit: 100,
            total: 'true'
          })
          .reply(200, require('./fixtures/incident_list-empty.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager res', ->
          it 'says there is no incidents', ->
            expect(hubotResponse())
            .to.eql 'There is no acknowledged incidents at the moment.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager res PT4KHLK"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .put('/incidents')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager res PT4KHLK', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager res PT4KHLK', ->
            it 'says incident was resolved', ->
              expect(hubotResponse())
              .to.eql 'Incident PT4KHLK resolved.'

        context 'with many incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage_multi-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager res PT4KHLK,1234567', ->
            it 'says incidents wer resolved', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 resolved.'

          say 'pager res PT4KHLK 1234567', ->
            it 'says incidents wer resolved', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 resolved.'

          say 'pager res PT4KHLK, 1234567', ->
            it 'says incidents wer resolved', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 resolved.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager assign all to me"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .query({
            time_zone: 'UTC',
            urgencies: [
              'high'
            ],
            sort_by: 'created_at',
            date_range: 'all',
            statuses: [
              'triggered',
              'acknowledged'
            ],
            limit: 100,
            total: 'true'
          })
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager assign all to me', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              date_range: 'all',
              statuses: [
                'triggered',
                'acknowledged'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list-ok.json'))
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage-ok.json'))

          afterEach ->
            nock.cleanAll()

          say 'pager assign all to me', ->
            it 'says incident was assigned', ->
              expect(hubotResponse())
              .to.eql 'Incident PT4KHLK assigned to momo.'

        context 'with many incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              date_range: 'all',
              statuses: [
                'triggered',
                'acknowledged'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list-ok.json'))
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage_multi-ok.json'))

          afterEach ->
            nock.cleanAll()

          say 'pager assign all to me', ->
            it 'says incident was assigned', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 assigned to momo.'

          say 'pager assign all to toto', ->
            it 'says toto is unknown', ->
              expect(hubotResponse())
              .to.eql 'Sorry, I can\'t figure toto email address. ' +
                      'Can you ask them to `.pager me as <email>`?'


      context 'when there are no incidents,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .query({
            time_zone: 'UTC',
            urgencies: [
              'high'
            ],
            sort_by: 'created_at',
            date_range: 'all',
            statuses: [
              'triggered',
              'acknowledged'
            ],
            limit: 100,
            total: 'true'
          })
          .reply(200, require('./fixtures/incident_list-empty.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager assign all to me', ->
          it 'says there are no incidents', ->
            expect(hubotResponse())
            .to.eql 'There is no incidents at the moment.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager assign PT4KHLK to me"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .put('/incidents')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager assign PT4KHLK to me', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager assign PT4KHLK to me', ->
            it 'says incident was assigned', ->
              expect(hubotResponse())
              .to.eql 'Incident PT4KHLK assigned to momo.'

        context 'with many incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage_multi-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager assign PT4KHLK,1234567 to me', ->
            it 'says incident was assigned', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 assigned to momo.'

          say 'pager assign PT4KHLK 1234567 to me', ->
            it 'says incident was assigned', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 assigned to momo.'

          say 'pager assign PT4KHLK, 1234567 to me', ->
            it 'says incident was assigned', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 assigned to momo.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager snooze all"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .query({
            time_zone: 'UTC',
            urgencies: [
              'high'
            ],
            sort_by: 'created_at',
            date_range: 'all',
            statuses: [
              'triggered',
              'acknowledged'
            ],
            limit: 100,
            total: 'true'
          })
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager snooze all', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              date_range: 'all',
              statuses: [
                'triggered',
                'acknowledged'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list-ok.json'))
            .post('/incidents/PT4KHLK/snooze')
            .reply(200, require('./fixtures/incident_snooze-ok.json'))

          afterEach ->
            nock.cleanAll()

          say 'pager snooze all', ->
            it 'says all incidents have been snoozed', ->
              expect(hubotResponse())
              .to.eql 'Incident PT4KHLK snoozed.'

        context 'with many incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents')
            .query({
              time_zone: 'UTC',
              urgencies: [
                'high'
              ],
              sort_by: 'created_at',
              date_range: 'all',
              statuses: [
                'triggered',
                'acknowledged'
              ],
              limit: 100,
              total: 'true'
            })
            .reply(200, require('./fixtures/incident_list_multi-ok.json'))
            .post('/incidents/PT4KHLK/snooze')
            .reply(200, require('./fixtures/incident_snooze-ok.json'))
            .post('/incidents/1234567/snooze')
            .reply(200, require('./fixtures/incident_snooze_alt-ok.json'))

          afterEach ->
            nock.cleanAll()

          say 'pager snooze all', ->
            it 'says all incidents have been snoozed', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 snoozed.'

      context 'when there are no incidents,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .query({
            time_zone: 'UTC',
            urgencies: [
              'high'
            ],
            sort_by: 'created_at',
            date_range: 'all',
            statuses: [
              'triggered',
              'acknowledged'
            ],
            limit: 100,
            total: 'true'
          })
          .reply(200, require('./fixtures/incident_list-empty.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager snooze all', ->
          it 'says there are no incidents', ->
            expect(hubotResponse())
            .to.eql 'There is no open incidents at the moment.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager snooze PT4KHLK"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .post('/incidents/PT4KHLK/snooze')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager snooze PT4KHLK', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .post('/incidents/PT4KHLK/snooze')
            .reply(200, require('./fixtures/incident_snooze-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager snooze PT4KHLK', ->
            it 'says incident have been snoozed', ->
              expect(hubotResponse())
              .to.eql 'Incident PT4KHLK snoozed.'

        context 'with many incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .post('/incidents/PT4KHLK/snooze')
            .reply(200, require('./fixtures/incident_snooze-ok.json'))
            .post('/incidents/1234567/snooze')
            .reply(200, require('./fixtures/incident_snooze_alt-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pager snooze PT4KHLK,1234567', ->
            it 'says incident have been snoozed', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 snoozed.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager note PT4KHLK some note"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .post('/incidents/PT4KHLK/notes')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager note PT4KHLK some note', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .post('/incidents/PT4KHLK/notes')
          .reply(200, require('./fixtures/note_create-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager note PT4KHLK some note', ->
          it 'says note has been added', ->
            expect(hubotResponse())
            .to.eql 'Note added to PT4KHLK: some note.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager notes PT4KHLK"', ->
      context 'when something goes wrong once,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents/PT4KHLK/notes')
          .reply(503, "503 it's all broken!")
          .get('/incidents/PT4KHLK/notes')
          .reply(200, require('./fixtures/notes_list-ok.json'))
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager notes PT4KHLK', ->
          it 'silently retry and succeed', ->
            expect(hubotResponse())
            .to.eql 'PT4KHLK - Firefighters are on the scene.'
      context 'when something goes wrong twice,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents/PT4KHLK/notes')
          .reply(503, { error: { code: 503, message: "it's all broken!" } })
          .get('/incidents/PT4KHLK/notes')
          .reply(503, { error: { code: 503, message: "it's all broken!" } })
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager notes PT4KHLK', ->
          it 'silently retry and fail', ->
            expect(hubotResponse())
            .to.eql "503 it\'s all broken!"
      
      context 'when something goes wrong once with unexpected error,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents/PT4KHLK/notes')
          .reply(502, 'gatewaytimeout')
          .get('/incidents/PT4KHLK/notes')
          .reply(200, require('./fixtures/notes_list-ok.json'))
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager notes PT4KHLK', ->
          it 'silently retry and succeed', ->
            expect(hubotResponse())
            .to.eql 'PT4KHLK - Firefighters are on the scene.'

      context 'when something goes wrong twice with unexpected error,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents/PT4KHLK/notes')
          .reply(502, 'gatewaytimeout')
          .get('/incidents/PT4KHLK/notes')
          .reply(502, 'gatewaytimeout')
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager notes PT4KHLK', ->
          it 'silently retry and fail', ->
            expect(hubotResponse())
            .to.eql 'Unable to read request output'



      context 'when there are no notes,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents/PT4KHLK/notes')
          .reply(200, require('./fixtures/notes_empty-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager notes PT4KHLK', ->
          it 'returns a message warning that there is no notes', ->
            expect(hubotResponse())
            .to.eql 'PT4KHLK has no notes.'

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents/PT4KHLK/notes')
          .reply(200, require('./fixtures/notes_list-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager notes PT4KHLK', ->
          it 'returns notes for the incident', ->
            expect(hubotResponse())
            .to.eql 'PT4KHLK - Firefighters are on the scene.'


    # ----------------------------------------------------------------------------------------------
    describe '".pager maintenances"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/maintenance_windows')
          .query({
            filter: 'ongoing'
          })
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager maintenances', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/maintenance_windows')
          .query({
            filter: 'ongoing'
          })
          .reply(200, require('./fixtures/maintenance_list-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager maintenances', ->
          it 'returns ongoing maintenances', ->
            expect(hubotResponse())
            .to.eql 'PW98YIO - Immanentizing the eschaton (until 03:00 UTC) on My Mail Service'
      
      context 'when there is no maintenance', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/maintenance_windows')
          .query({
            filter: 'ongoing'
          })
          .reply(200, require('./fixtures/maintenance_list-empty.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager maintenances', ->
          it 'returns ongoing maintenances', ->
            expect(hubotResponse())
            .to.eql 'There is no ongoing maintenance at the moment.'

    # ----------------------------------------------------------------------------------------------
    describe '".pager extensions"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/extensions')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager extensions', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/extensions')
          .query({
            query: 'magic'
          })
          .reply(200, require('./fixtures/extensions_list-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager extensions magic', ->
          it 'returns existing extension', ->
            expect(hubotResponse())
            .to.eql '[789] something: magic button - Custom Incident Action'
      
      context 'when there is no matching extensions', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/extensions')
          .query({
            query: 'magic'
          })
          .reply(200, require('./fixtures/extensions_list-empty.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager extensions magic', ->
          it 'returns empty list', ->
            expect(hubotResponse())
            .to.eql 'No extension found'

    # ----------------------------------------------------------------------------------------------
    describe '".pager actions"', ->
      context 'when everything is fine but there is no named action', ->
        beforeEach ->
          room.robot.brain.data.pagerv2.custom_name = { }
        say 'pager actions', ->
          it 'returns that there is no actions', ->
            expect(hubotResponse())
            .to.eql 'No named action available'
      context 'when everything is fine and there are named actions', ->
        say 'pager actions', ->
          it 'returns existing extension', ->
            expect(hubotResponse())
            .to.eql '[maintenance] : pager_maintenance'
        say 'pager actions maintenance', ->
          it 'returns existing extension', ->
            expect(hubotResponse())
            .to.eql '[maintenance] : pager_maintenance'
        say 'pager actions maintenance_txt', ->
          it 'returns existing extension', ->
            expect(hubotResponse())
            .to.eql '[maintenance_txt] : create a maintenance'
        
    describe '".pager run"', ->
      context 'when the action is unknown', ->
        say 'pager run abc', ->
          it 'returns an error message', ->
            expect(hubotResponse())
            .to.eql 'Unknown action for name abc'
      context 'when the action i known', ->
        say 'pager run maintenance', ->
          it 'returns an acknowledgement', ->
            expect(hubotResponse())
            .to.eql 'Action "maintenance" sent'

    # ----------------------------------------------------------------------------------------------
    describe '".pager stfu services"', ->

      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/services')
          .query({
            query: 'My Application Service'
          })
          .reply(200, require('./fixtures/services_list1-ok.json'))
          .get('/services')
          .query({
            query: 'Other Service'
          })
          .reply(200, require('./fixtures/services_list2-ok.json'))
          .post('/maintenance_windows')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          nock.cleanAll()

        say 'pager stfu Other Service for 10 m', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          room.robot.brain.data.pagerv2.services['My Application Service'] = 'PIJ90N7'
          nock('https://api.pagerduty.com')
          .get('/services')
          .query({
            query: 'My Application Service'
          })
          .reply(200, require('./fixtures/services_list1-ok.json'))
          .get('/services')
          .query({
            query: 'Other Service'
          })
          .reply(200, require('./fixtures/services_list2-ok.json'))
          .post('/maintenance_windows')
          .reply(200, require('./fixtures/maintenance_create-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager stfu My Application Service for 60 minutes', ->
          it 'returns ongoing maintenances', ->
            expect(hubotResponse())
            .to.eql 'Maintenance created for My Application Service until ' +
                    'Tue 03:00 UTC (id PW98YIO).'
        say 'pager stfu * for 60 minutes', ->
          it 'returns ongoing maintenances', ->
            expect(hubotResponse())
            .to.eql 'Maintenance created for * until Tue 03:00 UTC (id PW98YIO).'
    # ----------------------------------------------------------------------------------------------
    describe '".pager stfu"', ->

      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/services')
          .query({
            query: 'My Application Service'
          })
          .reply(200, require('./fixtures/services_list1-ok.json'))
          .get('/services')
          .query({
            query: 'Other Service'
          })
          .reply(200, require('./fixtures/services_list2-ok.json'))
          .post('/maintenance_windows')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          nock.cleanAll()

        say 'pager stfu', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/services')
          .query({
            query: 'My Application Service'
          })
          .reply(200, require('./fixtures/services_list1-ok.json'))
          .get('/services')
          .query({
            query: 'Other Service'
          })
          .reply(200, require('./fixtures/services_list2-ok.json'))
          .post('/maintenance_windows')
          .reply(200, require('./fixtures/maintenance_create-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pager stfu', ->
          it 'returns ongoing maintenances', ->
            expect(hubotResponse())
            .to.eql 'Maintenance created for all services until Tue 03:00 UTC (id PW98YIO).'

    # ----------------------------------------------------------------------------------------------
    describe '".pager end PW98YIO"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .delete('/maintenance_windows/PW98YIO')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pager end PW98YIO', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .delete('/maintenance_windows/PW98YIO')
          .reply(200, '')
        afterEach ->
          nock.cleanAll()

        say 'pager end PW98YIO', ->
          it 'responds that the maintenance is now cancelled', ->
            expect(hubotResponse())
            .to.eql 'Maintenance ended.'

# --------------------------------------------------------------------------------------------------
  context 'permissions system', ->
    beforeEach ->
      process.env.HUBOT_AUTH_ADMIN = 'admin_user'
      process.env.PAGERV2_NEED_GROUP_AUTH = '1'
      room.robot.brain.data.pagerv2 = { users: { } }
      room.robot.loadFile path.resolve('node_modules/hubot-auth/src'), 'auth.coffee'
      room.robot.brain.userForId 'admin_user', {
        id: 'admin_user',
        name: 'admin_user'
      }
      room.robot.brain.data.pagerv2.users.admin_user = {
        name: 'admin_user',
        id: 'admin_user',
        email: 'toto@example.com',
        pagerid: '11111111'
      }
      room.robot.brain.userForId 'pager_admin', {
        id: 'pager_admin',
        name: 'pager_admin',
        phid: 'PHID-USER-123456789',
        roles: [
          'pageradmin'
        ]
      }
      room.robot.brain.data.pagerv2.users.pager_admin = {
        name: 'pager_admin',
        id: 'pager_admin',
        email: 'toto@example.com',
        pagerid: '87654321'
      }
      room.robot.brain.userForId 'pager_user', {
        id: 'pager_user',
        name: 'pager_user',
        roles: [
          'pageruser'
        ]
      }
      room.robot.brain.data.pagerv2.users.pager_user = {
        name: 'pager_user',
        id: 'pager_user',
        email: 'toto@example.com',
        pagerid: '12345678'
      }
      room.robot.brain.userForId 'non_pager_user', {
        id: 'non_pager_user',
        name: 'non_pager_user'
      }
      room.receive = (userName, message) ->
        new Promise (resolve) =>
          @messages.push [userName, message]
          user = @robot.brain.userForName(userName)
          @robot.receive(new Hubot.TextMessage(user, message), resolve)


    afterEach ->
      delete process.env.HUBOT_AUTH_ADMIN
      delete process.env.PAGERV2_NEED_GROUP_AUTH
      room.robot.brain.data.pagerv2 = { }


    context 'user wants to resolve an alert', ->
      beforeEach ->
        do nock.disableNetConnect
        nock('https://api.pagerduty.com')
        .put('/incidents')
        .reply(200, require('./fixtures/incident_manage-ok.json'))

      afterEach ->
        nock.cleanAll()

      context 'and user is admin', ->
        hubot 'pager res PT4KHLK', 'admin_user'
        it 'says incident was resolved', ->
          expect(hubotResponse())
          .to.eql 'Incident PT4KHLK resolved.'

      context 'and user is pager_admin', ->
        hubot 'pager res PT4KHLK', 'pager_admin'
        it 'says incident was resolved', ->
          expect(hubotResponse())
          .to.eql 'Incident PT4KHLK resolved.'

      context 'and user is pager_user', ->
        hubot 'pager res PT4KHLK', 'pager_user'
        it 'says incident was resolved', ->
          expect(hubotResponse())
          .to.eql 'Incident PT4KHLK resolved.'

      context 'and user is not in pager_user', ->
        hubot 'pager res PT4KHLK', 'non_pager_user'
        it 'warns the user that he has no permission to use that command', ->
          expect(hubotResponse()).to.eql 'You don\'t have permission to do that.'


    describe '".pager <user> as <email>"', ->
      context 'by an unauthorized user,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/users')
          .query({
            query: 'toto@example.com'
          })
          .reply 200, require('./fixtures/users_list-match.json')
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        context 'pager who is toto', ->
          hubot 'pager who is toto', 'admin_user'
          it 'returns information from pager', ->
            expect(hubotResponse())
            .to.eql 'Sorry, I can\'t figure toto email address. ' +
                    'Can you help me with `.pager toto as <email>`?'

        context 'pager who is toto', ->
          hubot 'pager who is toto', 'pager_admin'
          it 'returns information from pager', ->
            expect(hubotResponse())
            .to.eql 'Sorry, I can\'t figure toto email address. ' +
                    'Can you help me with `.pager toto as <email>`?'



# --------------------------------------------------------------------------------------------------
