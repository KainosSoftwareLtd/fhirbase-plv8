utils = require('../core/utils')
sql = require('../honey')
moment = require('../../node_modules/moment-timezone/builds/moment-timezone-with-data.min.js')

process = (arg, i)->
  logMaxL = 90;
  if arg instanceof Object 
    arg = JSON.stringify(arg)
  if typeof arg == "string" && arg.length > logMaxL
    overflow[i] = arg.substring(50)
    arg = arg.substring(0, 50)

  return arg
  
log = ()->
  overflow = []
  args = Array.prototype.slice.call(arguments, 0).map(process)
  plv8.elog.apply(this, [NOTICE].concat(args))
  if overflow.length
    log.apply(this,overflow)

load_configuration_time = (plv8)->
  res = utils.exec plv8,
    select: sql.raw('timezone')
    from: sql.q("timezone_configuration")

  row = res[0]
  if typeof row == "object"
    row = row.timezone
  
  return row


get_default_time = (plv8, date)->
  if typeof plv8 == "undefined"
    configuration_timezone = 'Europe/London'
  else
    configuration_timezone = load_configuration_time(plv8)

  date_moment = moment(date)
  format_apply = moment.tz(date_moment, configuration_timezone).format('Z')

  log("get_default_time " + date_moment + " format " + format_apply)

  format_apply



exports.log = log
exports.get_default_time = get_default_time
