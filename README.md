Hubot-pager-v2
==================

[![Build Status](https://img.shields.io/travis/Gandi/hubot-pager-v2.svg)](https://travis-ci.org/Gandi/hubot-pager-v2)
[![Dependency Status](https://gemnasium.com/Gandi/hubot-pager-v2.svg)](https://gemnasium.com/Gandi/hubot-pager-v2)
[![Coverage Status](http://img.shields.io/codeclimate/coverage/github/Gandi/hubot-pager-v2.svg)](https://codeclimate.com/github/Gandi/hubot-pager-v2/coverage)

Work in progress, very early stage

This plugin is based on the usage we have in Gandi of Pagerduty. It may, in its first instance, not match your setup, so please verify that first.

- we have on main schedule that is for the general alert dispatch (`PAGERV2_SCHEDULE_ID`)
- only one person is on call at any given time
- we don't use teams

Configuration
---------------

    # pager v2 configuration vars
    export PAGERV2_API_KEY=""
    export PAGERV2_SCHEDULE_ID=""
    export PAGERV2_OVERRIDERS=""
    export PAGERV2_SERVICES="name1,name2"
    export PAGERV2_DEFAULT_RESOLVER="nagios"
    export PAGERV2_ENDPOINT="/hook"
    export PAGERV2_ANNOUNCE_ROOM="#dev"
    export PAGERV2_NEED_GROUP_AUTH="0"
    export PAGERV2_LOG_PATH="/tmp"

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

- [@mose](https://github.com/mose) - author and maintainer

### License

This source code is available under [MIT license](LICENSE).

### Copyright

Copyright (c) 2017 - Gandi - https://gandi.net
