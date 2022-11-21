# strava_activities_updater

Small script to update Strava activities accroding to the pattern below:

```ruby
ACTIVITIES_MAPPING = {
  /run/i => '🏃',
  /weight/i => '🏋️‍♀️',
  /ride/i => '🚴‍♂️'
}.freeze
```
