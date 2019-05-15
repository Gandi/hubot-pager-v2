Hubot-pager-v2
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

TODO: explain what each configuration variable is meant for.

Usage
--------

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

### License

This source code is available under [MIT license](LICENSE).

### Copyright

Copyright (c) 2017 - Gandi - https://gandi.net
