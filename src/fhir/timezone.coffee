moment = require('../../node_modules/moment-timezone/builds/moment-timezone-with-data.min.js')

get_default_time = (plv8, date)->
  configuration_timezone = 'Europe/London'
  date_moment = moment(date)

  moment.tz(date_moment, configuration_timezone).format('Z')

exports.get_default_time = get_default_time
