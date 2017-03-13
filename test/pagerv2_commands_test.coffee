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

  # ------------------------------------------------------------------------------------------------
  describe '".pd next oncall"', ->
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
    describe '".pd incident 1234"', ->
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
      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .reply(200, require('./fixtures/incident_list-ok.json'))

        afterEach ->
          nock.cleanAll()

        say 'pd sup', ->
          it 'returns list of incidents', ->
            expect(hubotResponse())
            .to.eql 'PT4KHLK (resolved) The server is on fire.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd ack"', ->
      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .reply(200, require('./fixtures/incident_list-ok.json'))
          .put('/incidents')
          .reply(200, require('./fixtures/incident_manage-ok.json'))

        afterEach ->
          nock.cleanAll()

        say 'pd ack', ->
          it 'says incident was acknowledged', ->
            expect(hubotResponse())
            .to.eql 'Incident PT4KHLK acknowledged.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd ack PT4KHLK"', ->
      context 'when everything goes right,', ->
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

    # ----------------------------------------------------------------------------------------------
    describe '".pd res"', ->
      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .reply(200, require('./fixtures/incident_list-ok.json'))
          .put('/incidents')
          .reply(200, require('./fixtures/incident_manage-ok.json'))

        afterEach ->
          nock.cleanAll()

        say 'pd res', ->
          it 'says incident was resolved', ->
            expect(hubotResponse())
            .to.eql 'Incident PT4KHLK resolved.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd res PT4KHLK"', ->
      context 'when everything goes right,', ->
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

    # ----------------------------------------------------------------------------------------------
    describe '".pd assign all to me"', ->
      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .reply(200, require('./fixtures/incident_list-ok.json'))
          .put('/incidents')
          .reply(200, require('./fixtures/incident_manage-ok.json'))

        afterEach ->
          nock.cleanAll()

        say 'pd assign all to me', ->
          it 'says incident was assigned', ->
            expect(hubotResponse())
            .to.eql 'Incident PT4KHLK assigned to momo.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd assign PT4KHLK to me"', ->
      context 'when everything goes right,', ->
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

    # ----------------------------------------------------------------------------------------------
    describe '".pd snooze all"', ->
      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/incidents')
          .reply(200, require('./fixtures/incident_list-ok.json'))
          .post('/incidents/PT4KHLK/snooze')
          .reply(200, require('./fixtures/incident_snooze-ok.json'))

        afterEach ->
          nock.cleanAll()

        say 'pd snooze all', ->
          it 'says all incidents have been snoozed', ->
            expect(hubotResponse())
            .to.eql 'Incident PT4KHLK snoozed.'

    # ----------------------------------------------------------------------------------------------
    describe '".pd snooze PT4KHLK"', ->
      context 'when everything goes right,', ->
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

    # ----------------------------------------------------------------------------------------------
    describe '".pd note PT4KHLK some note"', ->
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
      context 'when everything goes right,', ->
        beforeEach ->
          nock('https://api.pagerduty.com')
          .get('/maintenance windows')
          .reply(200, require('./fixtures/maintenance_list-ok.json'))

        afterEach ->
          nock.cleanAll()

        say 'pd maintenances', ->
          it 'returns ongoing maintenances', ->
            expect(hubotResponse())
            .to.eql 'PW98YIO - Immanentizing the eschaton (until 03:00 UTC)'

    # ----------------------------------------------------------------------------------------------
    describe '".pd stfu"', ->
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
