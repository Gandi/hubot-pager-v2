Hubot-pager-v2 and v3 webhooks
==================

[![Version](https://img.shields.io/npm/v/hubot-pager-v2.svg)](https://www.npmjs.com/package/hubot-pager-v2)
[![Downloads](https://img.shields.io/npm/dt/hubot-pager-v2.svg)](https://www.npmjs.com/package/hubot-pager-v2)
[![Build Status](https://img.shields.io/travis/Gandi/hubot-pager-v2.svg)](https://travis-ci.org/Gandi/hubot-pager-v2)
[![Dependency Status](https://gemnasium.com/Gandi/hubot-pager-v2.svg)](https://gemnasium.com/Gandi/hubot-pager-v2)
[![Coverage Status](http://img.shields.io/codeclimate/coverage/github/Gandi/hubot-pager-v2.svg)](https://codeclimate.com/github/Gandi/hubot-pager-v2/coverage)

This plugin is based on the usage we have in Gandi of Pagerduty. It may, in its first instance, not match your setup, so please verify that first.

- we have on main schedule that is for the general alert dispatch (`PAGERV2_SCHEDULE_ID`)
- only one person is on call at any given time
- we don't use teams

V3 Webhooks Subscriptions
-----------
We have added support to V3 Subscriptions, [follow the official guide](https://support.pagerduty.com/docs/webhooks#migrating-from-v1v2-generic-extensions-to-v3-webhook-subscriptions) for more information about how to migrate from Webhooks V1/V2 to V3.


Configuration
---------------

    # pager v2 configuration vars
    export PAGERV2_API_KEY=""
    export PAGERV2_SCHEDULE_ID=""
    export PAGERV2_SERVICES="name1,name2"
    export PAGERV2_DEFAULT_RESOLVER="nagios"
    export PAGERV2_ENDPOINT="/hook"
    export PAGERV2_ANNOUNCE_ROOM="#dev"
    export PAGERV2_NEED_GROUP_AUTH="0"
    export PAGERV2_LOG_PATH="/tmp"
    export PAGERV2_CUSTOM_ACTION_FILE="file.json"


PAGERV2_API_KEY contains the pagerduty api key for v2 api.
PAGERV2_SCHEDULE_ID contains the default schedule for oncall and override
PAGERV2_SERVICES contains the name of the service, separated by comma, of the service to monitor/interact with
PAGERV2_DEFAULT_RESOLVER="nagios" in case no resolver is found, use this one
PAGERV2_ENDPOINT="/hook" the path used to setup the webhook. be sure it is not already in use.
PAGERV2_ANNOUNCE_ROOM="#dev" where to announce webhook message
PAGERV2_NEED_GROUP_AUTH="0" if weither or not (0,1) you need authentication for interacting with pagerduty
PAGERV2_LOG_PATH="/tmp" where to save the log of pager
PAGERV2_CUSTOM_ACTION_FILE="file.json" this contains the custom action binding in the form { action_id : { action : 'action_name', args : {...} } } The action name refer to an available command from this module or another (will do a robot.emit action_id.action action_id.args)



Usage
--------

In the while, `hubot help pager` should list you all available commands.
=======
you can use `hubot help pager` to list all available commands :

    .pager <user> as <email>   - declare what email should be use to find <user> pagerduty id
    .pager [who is] next [oncall] - tells who is next on call
    .pager [who is] oncall        - tells who is currently on call
    .pager ack <#,#,#>         - acknowledges incident <number>
    .pager ack [all]           - acknowledges any unack incidents
    .pager assign <#,#,#> to <user> - assigns incidents <#,#,#> to user
    .pager assign <#,#,#> to me     - assigns incidents <#,#,#> to caller
    .pager assign [all] to <user>   - assigns all open incidents to user
    .pager assign [all] to me       - assigns all open incidents to caller
    .pager end <maintenance> - ends <maintenance>
    .pager incident <#>        - gives more information about incident number <number>
    .pager maintenances           - lists currently active maintenances
    .pager extensions [name]   - list extensions filtered by name. relevant for custom_action
    .pager me                  - check if the caller is known by pagerduty plugin
    .pager me <duration>       - creates an override for <duration> minutes
    .pager me as <email>       - declare what email should be use to find caller pagerduty id
    .pager me next             - creates an override for the next scheduled
    .pager me now              - creates an override until the end of current oncall
    .pager noc <duration>      - creates an override for <duration> minutes with the noc account
    .pager noc now             - creates a noc override until the end of current oncall
    .pager not me              - cancels an override if any
    .pager not noc             - cancels a noc override if any
    .pager note <#,#,#> <note> - create a note for incidents <#,#,#>
    .pager notes <#>           - read notes for incident <#>
    .pager oncall <message>       - cc oncall and send <message> to alerting channel
    .pager res|resolve <#,#,#> - resolves incident <number>
    .pager res|resolve [all]   - resolves any un-resolved incidents
    .pager snooze <#,#,#> [for] [<duration>] [min] - snoozes incident <number>
    .pager snooze [all] [for] [<duration>] [min]   - snoozes any open incidents for [<duration>] (default 120m)
    .pager stfu|down <service,service,service> for <duration> [because <reason>] - creates a maintenance per service
    .pager stfu|down [for] <duration> [because <reason>] - creates a maintenance
    .pager sup|inc|incidents   - lists currently unresolved incidents
    .pager version             - give the version of hubot-pager-v2 loaded
    .pager who is <user>       - check if the caller is known by pagerduty plugin 

Development
--------------

### Changelog

All changes are listed in the [CHANGELOG](CHANGELOG.md)

### Testing

    npm install

    # will run make test and coffeelint
    npm test 
    
    # or
    make test
    
    # or, for watch-mode
    make test-w

    # or for more documentation-style output
    make test-spec

    # and to generate coverage
    make test-cov

    # and to run the lint
    make lint

    # run the lint and the coverage
    make


### Contribute

Feel free to open a PR if you find any bug, typo, want to improve documentation, or think about a new feature. 

Gandi loves Free and Open Source Software. This project is used internally at Gandi but external contributions are **very welcome**. 

Attribution
-----------

### Authors

- [@mose](https://github.com/mose) - author
- [@baptistem](https://github.com/baptistem) - author and maintainer
- [@araujobsd](https://github.com/araujobsd) - contributor

### License

This source code is available under [MIT license](LICENSE).

### Copyright

Copyright (c) 2022 - Gandi - https://gandi.net
