Hubot-pager-v2 Changelog
==========================
### 1.1.17   2022-12-15
 - support v3 webhooks subscriptions

### 1.1.16   2020-06-18
 - fix grafana detail fetching
 - add missing schedule test case

### 1.1.15   2020-05-15
 - fix incident listing with sup sharing id

### 1.1.14   2020-05-12
 - remove log flooding
 - add alerts log fallback

### 1.1.13   2020-05-07
 - support alerts and priority

### 1.1.12   2020-04-09
 - add pager steal 

### 1.1.11   2020-04-06
 - add responder workflow

### 1.1.10   2020-03-31
 - fix multi assignement display

### 1.1.9   2020-03-24
 - fix inconsistency with schedule message

### 1.1.8   2020-03-23
 - send a message to a given oncall

### 1.1.7   2020-03-05
 - pager schedules and schedule
 - refactoring oncall code for cleaner code

### 1.1.6   2020-02-26
 - use the same code when printing Incident
 - limit concurency for listing notes to 2

### 1.1.5   2020-02-06
 - retry when encountering a 429

### 1.1.4   2019-12-10
- improve webhook v2 support

### 1.1.3   2019-11-04
- fix custom action import issue 

### 1.1.2 - 2019-09-12
- add retry for failed requests

### 1.1.0 - 2019-08-08
- add custom action listening to webhook
- add partial support for webhook v2

### 1.0.0 - 2017-06-18
- full implementation of all commands
- add maintenance commands per service
- add .oncall <message>
- 100% test coverage
- improve response messages

### 0.1.1 - 2017-05-26
- fix overrides with 'me'

### 0.1.0 - 2017-05-26
- covering previously managed pagerduty calls from Gandi internal plugin
- initial skeleton
