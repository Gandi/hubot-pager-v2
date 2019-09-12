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

  beforeEach ->
    process.env.PAGERV2_API_KEY = 'xxx'
    process.env.PAGERV2_SCHEDULE_ID = '42'
    process.env.PAGERV2_ANNOUNCE_ROOM = '#dev'
    process.env.PAGERV2_ENDPOINT = '/test_hook'
    process.env.PAGERV2_CUSTOM_ACTION_FILE = './test/fixtures/custom_action.json'
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

    nock('https://api.pagerduty.com')
    .get('/incidents')
    .query(
      {
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
      }
    )
    .reply(200, require('./fixtures/incident_list-ok.json'))
    .get('/incidents/PT4KHLK/notes')
    .reply(200, require('./fixtures/notes_list-ok.json'))


  afterEach ->
    delete process.env.PAGERV2_API_KEY
    delete process.env.PAGERV2_SCHEDULE_ID
    delete process.env.PAGERV2_ANNOUNCE_ROOM
    delete process.env.PAGERV2_ENDPOINT
    delete process.env.PORT
    room.destroy()

# -------------------------------------------------------------------------------------------------
  context 'it get all Incident with note', ->

    it 'should answer', ->
      pagerv2 = new Pagerv2 room.robot
      pagerv2.listIncidentsWithNotes()
      .then (announce) ->
        expect(announce).to.eql require('./fixtures/list_incident.json')

# -------------------------------------------------------------------------------------------------
  context 'it set color', ->

    it 'should color irc', ->
      pagerv2 = new Pagerv2 room.robot
      result = pagerv2.colorer('irc', 'trigger', 'test')
      expect(result).to.eql '\u000304\u0002\u0002test\u0003'

  context 'the request is broken', ->
    before ->
      nock('https://api.pagerduty.com')
      .get('/bug')
      .reply('200', 'this is not a json reply')
    it 'should return the error', ->
      pagerv2 = new Pagerv2 room.robot
      
      pagerv2.request('GET', '/bug', { })
      .catch (e) ->
        expect(e).to.eql 'Unable to read request output'
