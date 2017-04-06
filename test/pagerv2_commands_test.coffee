require('es6-promise').polyfill()

Helper = require 'hubot-test-helper'
helper = new Helper('../scripts/pagerv2_commands.coffee')
Hubot = require '../node_modules/hubot'

path   = require 'path'
nock   = require 'nock'
sinon  = require 'sinon'
moment = require 'moment'
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
        .get('/users?query=momo%40example.com')
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
        .get('/users?query=toto%40example.com')
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
        .get('/users?query=toto%40example.com')
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
        .get('/users?query=toto%40example.com')
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
        .get('/users?query=toto%40example.com')
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
    context 'when something goes wrong,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/oncalls?time_zone=UTC&schedule_ids%5B%5D=42&earliest=true')
        .reply 503, { error: { code: 503, message: "it's all broken!" } }
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd oncall', ->
        it 'returns the error message', ->
          expect(hubotResponse())
          .to.eql "503 it's all broken!"

    context 'when everything goes right,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/oncalls?time_zone=UTC&schedule_ids%5B%5D=42&earliest=true')
        .reply 200, require('./fixtures/oncall_list-ok.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd oncall', ->
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
        .get('/oncalls?time_zone=UTC&schedule_ids%5B%5D=42&earliest=true')
        .reply 200, payload
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd oncall', ->
        it 'returns name of who is on call', ->
          expect(hubotResponse())
          .to.eql "Tim Wright is on call until #{@end_time.format('HH:mm')} (utc)."

  # ------------------------------------------------------------------------------------------------
  describe '".pd next oncall"', ->
    context 'when something goes wrong,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/oncalls?time_zone=UTC&schedule_ids%5B%5D=42&earliest=true')
        .reply 503, { error: { code: 503, message: "it's all broken!" } }
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd next oncall', ->
        it 'returns the error message', ->
          expect(hubotResponse())
          .to.eql "503 it's all broken!"

    context 'when everything goes right,', ->
      beforeEach ->
        room.robot.brain.data.pagerv2 = { users: { } }
        nock('https://api.pagerduty.com')
        .get('/oncalls?time_zone=UTC&schedule_ids%5B%5D=42&earliest=true')
        .reply(200, require('./fixtures/oncall_list-ok.json'))
        .filteringPath( (path) ->
          path.replace /(since|until)=[^&]*/g, '$1=x'
        )
        .get('/oncalls?time_zone=UTC&schedule_ids%5B%5D=42&earliest=true&since=x&until=x')
        .reply 200, require('./fixtures/oncall_list_next-ok.json')
      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd next oncall', ->
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
        .get('/oncalls?time_zone=UTC&schedule_ids%5B%5D=42&earliest=true')
        .reply(200, payload1)
        .get(
          '/oncalls?time_zone=UTC&schedule_ids%5B%5D=42&earliest=true' +
          '&since=' + encodeURIComponent(moment(@start_time).utc().add(2, 'minute').format()) +
          '&until=' + encodeURIComponent(moment(@start_time).utc().add(3, 'minute').format())
        )
        .reply(200, payload2)

      afterEach ->
        room.robot.brain.data.pagerv2 = { }
        nock.cleanAll()

      say 'pd next oncall', ->
        it 'returns name of who is on call', ->
          expect(hubotResponse())
          .to.eql "Bea Blala will be next on call at #{@start_time.format('HH:mm')} " +
                  "until #{@end_time.format('HH:mm')} (utc)."


  # ================================================================================================
  context 'caller is known', ->
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

      afterEach ->
        room.robot.brain.data.pagerv2 = { }

    # ----------------------------------------------------------------------------------------------
    describe '".pd 120000"', ->
      context 'when everything goes right,', ->
        say 'pd 120000', ->
          it 'warns that this duration does not make any sense', ->
            expect(hubotResponse())
            .to.eql 'Sorry you cannot set an override of more than 1 day.'

    describe '".pd 120"', ->
      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/oncalls?time_zone=UTC&schedule_ids%5B%5D=42&earliest=true')
          .reply(200, require('./fixtures/oncall_list-ok.json'))
          .post('/schedules/42/overrides')
          .reply(200, require('./fixtures/override_create-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pd 120', ->
          it 'says override is done', ->
            expect(hubotResponse())
            .to.eql 'Rejoice Aurelio Rice! momo is now on call.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd not me"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .filteringPath( (path) ->
            path.replace /(since|until)=[^&]*/g, '$1=x'
          )
          .get('/schedules/42/overrides?since=x&until=x&editable=true&overflow=true')
          .reply(200, require('./fixtures/override_get-ok.json'))
          .delete('/schedules/42/overrides/PQ47DCP')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd not me', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .filteringPath( (path) ->
            path.replace /(since|until)=[^&]*/g, '$1=x'
          )
          .get('/schedules/42/overrides?since=x&until=x&editable=true&overflow=true')
          .reply(200, require('./fixtures/override_get-ok.json'))
          .delete('/schedules/42/overrides/PQ47DCP')
          .reply(200, require('./fixtures/override_get-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pd not me', ->
          it 'returns name of who is on call', ->
            expect(hubotResponse())
            .to.eql 'Ok, momo! Aurelio Rice override is cancelled.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd me now"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/oncalls?time_zone=UTC&schedule_ids%5B%5D=42&earliest=true')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd me now', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/oncalls?time_zone=UTC&schedule_ids%5B%5D=42&earliest=true')
          .reply(200, require('./fixtures/oncall_list-ok.json'))
          .post('/schedules/42/overrides')
          .reply(200, require('./fixtures/override_create-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pd me now', ->
          it 'returns name of who is on call', ->
            expect(hubotResponse())
            .to.eql 'Rejoice Aurelio Rice! momo is now on call.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd incident 1234"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          room.robot.brain.data.pagerv2 = { users: { } }
          nock('https://api.pagerduty.com')
          .get('/incidents/1234')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd incident 1234', ->
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

        say 'pd incident 1234', ->
          it 'returns details on the incident', ->
            expect(hubotResponse())
            .to.eql 'PT4KHLK (resolved) The server is on fire.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd sup"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          room.robot.brain.data.pagerv2 = { users: { } }
          nock('https://api.pagerduty.com')
          .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
               '&statuses%5B%5D=triggered&statuses%5B%5D=acknowledged')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd sup', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'and there are no incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
                 '&statuses%5B%5D=triggered&statuses%5B%5D=acknowledged')
            .reply(200, require('./fixtures/incident_list-empty.json'))
          afterEach ->
            nock.cleanAll()

          say 'pd sup', ->
            it 'returns list of incidents', ->
              expect(hubotResponse())
              .to.eql 'There are no open incidents for now.'

        context 'and there are incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
                 '&statuses%5B%5D=triggered&statuses%5B%5D=acknowledged')
            .reply(200, require('./fixtures/incident_list-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pd sup', ->
            it 'returns list of incidents', ->
              expect(hubotResponse())
              .to.eql 'PT4KHLK (resolved) The server is on fire.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd ack"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
               '&statuses%5B%5D=triggered')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd ack', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
                 '&statuses%5B%5D=triggered')
            .reply(200, require('./fixtures/incident_list-ok.json'))
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pd ack', ->
            it 'says incident was acknowledged', ->
              expect(hubotResponse())
              .to.eql 'Incident PT4KHLK acknowledged.'

        context 'with multiple incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
                 '&statuses%5B%5D=triggered')
            .reply(200, require('./fixtures/incident_list_multi-ok.json'))
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage_multi-ok.json'))
          afterEach ->
            nock.cleanAll()

          say 'pd ack', ->
            it 'says incident was acknowledged', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 acknowledged.'

      context 'when there are no incidents,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all&' +
               'statuses%5B%5D=triggered')
          .reply(200, require('./fixtures/incident_list-empty.json'))
        afterEach ->
          nock.cleanAll()

        say 'pd ack', ->
          it 'says there is no incidents', ->
            expect(hubotResponse())
            .to.eql 'There is no triggered incidents at the moment.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd ack PT4KHLK"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .put('/incidents')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd ack PT4KHLK', ->
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

          say 'pd ack PT4KHLK', ->
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

          say 'pd ack PT4KHLK,1234567', ->
            it 'says incidents were acknowledged', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 acknowledged.'

          say 'pd ack PT4KHLK, 1234567', ->
            it 'says incidents were acknowledged', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 acknowledged.'

          say 'pd ack PT4KHLK 1234567', ->
            it 'says incidents were acknowledged', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 acknowledged.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd res"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all&' +
               'statuses%5B%5D=acknowledged')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd res', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all&' +
                 'statuses%5B%5D=acknowledged')
            .reply(200, require('./fixtures/incident_list-ok.json'))
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage-ok.json'))

          afterEach ->
            nock.cleanAll()

          say 'pd res', ->
            it 'says incident was resolved', ->
              expect(hubotResponse())
              .to.eql 'Incident PT4KHLK resolved.'

        context 'with many incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all&' +
                 'statuses%5B%5D=acknowledged')
            .reply(200, require('./fixtures/incident_list_multi-ok.json'))
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage_multi-ok.json'))

          afterEach ->
            nock.cleanAll()

          say 'pd res', ->
            it 'says incident was resolved', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 resolved.'

      context 'when there are no incidents,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all&' +
               'statuses%5B%5D=acknowledged')
          .reply(200, require('./fixtures/incident_list-empty.json'))
        afterEach ->
          nock.cleanAll()

        say 'pd res', ->
          it 'says there is no incidents', ->
            expect(hubotResponse())
            .to.eql 'There is no acknowledged incidents at the moment.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd res PT4KHLK"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .put('/incidents')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd res PT4KHLK', ->
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

          say 'pd res PT4KHLK', ->
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

          say 'pd res PT4KHLK,1234567', ->
            it 'says incidents wer resolved', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 resolved.'

          say 'pd res PT4KHLK 1234567', ->
            it 'says incidents wer resolved', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 resolved.'

          say 'pd res PT4KHLK, 1234567', ->
            it 'says incidents wer resolved', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 resolved.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd assign all to me"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
               '&statuses%5B%5D=triggered&statuses%5B%5D=acknowledged')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd assign all to me', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
                 '&statuses%5B%5D=triggered&statuses%5B%5D=acknowledged')
            .reply(200, require('./fixtures/incident_list-ok.json'))
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage-ok.json'))

          afterEach ->
            nock.cleanAll()

          say 'pd assign all to me', ->
            it 'says incident was assigned', ->
              expect(hubotResponse())
              .to.eql 'Incident PT4KHLK assigned to momo.'

        context 'with many incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
                 '&statuses%5B%5D=triggered&statuses%5B%5D=acknowledged')
            .reply(200, require('./fixtures/incident_list-ok.json'))
            .put('/incidents')
            .reply(200, require('./fixtures/incident_manage_multi-ok.json'))

          afterEach ->
            nock.cleanAll()

          say 'pd assign all to me', ->
            it 'says incident was assigned', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 assigned to momo.'

      context 'when there are no incidents,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
               '&statuses%5B%5D=triggered&statuses%5B%5D=acknowledged')
          .reply(200, require('./fixtures/incident_list-empty.json'))
        afterEach ->
          nock.cleanAll()

        say 'pd assign all to me', ->
          it 'says there are no incidents', ->
            expect(hubotResponse())
            .to.eql 'There is no incidents at the moment.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd assign PT4KHLK to me"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .put('/incidents')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd assign PT4KHLK to me', ->
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

          say 'pd assign PT4KHLK to me', ->
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

          say 'pd assign PT4KHLK,1234567 to me', ->
            it 'says incident was assigned', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 assigned to momo.'

          say 'pd assign PT4KHLK 1234567 to me', ->
            it 'says incident was assigned', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 assigned to momo.'

          say 'pd assign PT4KHLK, 1234567 to me', ->
            it 'says incident was assigned', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 assigned to momo.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd snooze all"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
               '&statuses%5B%5D=triggered&statuses%5B%5D=acknowledged')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd snooze all', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        context 'with only one incident', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
                 '&statuses%5B%5D=triggered&statuses%5B%5D=acknowledged')
            .reply(200, require('./fixtures/incident_list-ok.json'))
            .post('/incidents/PT4KHLK/snooze')
            .reply(200, require('./fixtures/incident_snooze-ok.json'))

          afterEach ->
            nock.cleanAll()

          say 'pd snooze all', ->
            it 'says all incidents have been snoozed', ->
              expect(hubotResponse())
              .to.eql 'Incident PT4KHLK snoozed.'

        context 'with many incidents', ->
          beforeEach ->
            nock('https://api.pagerduty.com')
            .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
                 '&statuses%5B%5D=triggered&statuses%5B%5D=acknowledged')
            .reply(200, require('./fixtures/incident_list_multi-ok.json'))
            .post('/incidents/PT4KHLK/snooze')
            .reply(200, require('./fixtures/incident_snooze-ok.json'))
            .post('/incidents/1234567/snooze')
            .reply(200, require('./fixtures/incident_snooze_alt-ok.json'))

          afterEach ->
            nock.cleanAll()

          say 'pd snooze all', ->
            it 'says all incidents have been snoozed', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 snoozed.'

      context 'when there are no incidents,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents?time_zone=UTC&include%5B%5D=first_trigger_log_entry&date_range=all' +
               '&statuses%5B%5D=triggered&statuses%5B%5D=acknowledged')
          .reply(200, require('./fixtures/incident_list-empty.json'))
        afterEach ->
          nock.cleanAll()

        say 'pd snooze all', ->
          it 'says there are no incidents', ->
            expect(hubotResponse())
            .to.eql 'There is no open incidents at the moment.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd snooze PT4KHLK"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .post('/incidents/PT4KHLK/snooze')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd snooze PT4KHLK', ->
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

          say 'pd snooze PT4KHLK', ->
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

          say 'pd snooze PT4KHLK 1234567', ->
            it 'says incident have been snoozed', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 snoozed.'

          say 'pd snooze PT4KHLK,1234567', ->
            it 'says incident have been snoozed', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 snoozed.'

          say 'pd snooze PT4KHLK, 1234567', ->
            it 'says incident have been snoozed', ->
              expect(hubotResponse())
              .to.eql 'Incidents PT4KHLK, 1234567 snoozed.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd note PT4KHLK some note"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .post('/incidents/PT4KHLK/notes')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd note PT4KHLK some note', ->
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

        say 'pd note PT4KHLK some note', ->
          it 'says note has been added', ->
            expect(hubotResponse())
            .to.eql 'Note added to PT4KHLK: some note.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd notes PT4KHLK"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents/PT4KHLK/notes')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd notes PT4KHLK', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents/PT4KHLK/notes')
          .reply(200, require('./fixtures/notes_list-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pd notes PT4KHLK', ->
          it 'returns notes for the incident', ->
            expect(hubotResponse())
            .to.eql 'PT4KHLK - Firefighters are on the scene.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd maintenances"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/maintenance windows?filter=ongoing')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd maintenances', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/maintenance windows?filter=ongoing')
          .reply(200, require('./fixtures/maintenance_list-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pd maintenances', ->
          it 'returns ongoing maintenances', ->
            expect(hubotResponse())
            .to.eql 'PW98YIO - Immanentizing the eschaton (until 03:00 UTC)'

    # ----------------------------------------------------------------------------------------------
    describe '".pd stfu"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .post('/maintenance windows')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd stfu', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .post('/maintenance windows')
          .reply(200, require('./fixtures/maintenance_create-ok.json'))
        afterEach ->
          nock.cleanAll()

        say 'pd stfu', ->
          it 'returns ongoing maintenances', ->
            expect(hubotResponse())
            .to.eql 'Maintenance created for all services until 03:00 UTC (id PW98YIO).'

    # ----------------------------------------------------------------------------------------------
    describe '".pd end PW98YIO"', ->
      context 'when something goes wrong,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .delete('/maintenance windows/PW98YIO')
          .reply 503, { error: { code: 503, message: "it's all broken!" } }
        afterEach ->
          room.robot.brain.data.pagerv2 = { }
          nock.cleanAll()

        say 'pd end PW98YIO', ->
          it 'returns the error message', ->
            expect(hubotResponse())
            .to.eql "503 it's all broken!"

      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .delete('/maintenance windows/PW98YIO')
          .reply(200, { })
        afterEach ->
          nock.cleanAll()

        say 'pd end PW98YIO', ->
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
        pdid: '11111111'
      }
      room.robot.brain.userForId 'pager_admin', {
        id: 'pager_admin',
        name: 'pager_admin',
        phid: 'PHID-USER-123456789',
        roles: [
          'pdadmin'
        ]
      }
      room.robot.brain.data.pagerv2.users.pager_admin = {
        name: 'pager_admin',
        id: 'pager_admin',
        email: 'toto@example.com',
        pdid: '87654321'
      }
      room.robot.brain.userForId 'pager_user', {
        id: 'pager_user',
        name: 'pager_user',
        roles: [
          'pduser'
        ]
      }
      room.robot.brain.data.pagerv2.users.pager_user = {
        name: 'pager_user',
        id: 'pager_user',
        email: 'toto@example.com',
        pdid: '12345678'
      }
      room.robot.brain.userForId 'non_pager_user', {
        id: 'non_pager_user',
        name: 'non_pager_user'
      }

    afterEach ->
      delete process.env.HUBOT_AUTH_ADMIN
      delete process.env.PAGERV2_NEED_GROUP_AUTH


    context 'user wants to resolve an alert', ->
      beforeEach ->
        room.receive = (userName, message) ->
          new Promise (resolve) =>
            @messages.push [userName, message]
            user = @robot.brain.userForName(userName)
            @robot.receive(new Hubot.TextMessage(user, message), resolve)

        do nock.disableNetConnect
        nock('https://api.pagerduty.com')
        .put('/incidents')
        .reply(200, require('./fixtures/incident_manage-ok.json'))

      afterEach ->
        nock.cleanAll()

      context 'and user is admin', ->
        hubot 'pd res PT4KHLK', 'admin_user'
        it 'says incident was resolved', ->
          expect(hubotResponse())
          .to.eql 'Incident PT4KHLK resolved.'

      context 'and user is pager_admin', ->
        hubot 'pd res PT4KHLK', 'pager_admin'
        it 'says incident was resolved', ->
          expect(hubotResponse())
          .to.eql 'Incident PT4KHLK resolved.'

      context 'and user is pager_user', ->
        hubot 'pd res PT4KHLK', 'pager_user'
        it 'says incident was resolved', ->
          expect(hubotResponse())
          .to.eql 'Incident PT4KHLK resolved.'

      context 'and user is not in pager_user', ->
        hubot 'pd res PT4KHLK', 'non_pager_user'
        it 'warns the user that he has no permission to use that command', ->
          expect(hubotResponse()).to.eql 'You don\'t have permission to do that.'

# --------------------------------------------------------------------------------------------------
