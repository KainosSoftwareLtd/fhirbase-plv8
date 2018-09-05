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

  log(res)

  row = res[0]
  if typeof row == "object"
    row = row.timezone
  
  log(row)

  return row


get_default_time = (plv8)->
  log("Get default time")
  log(moment("2013-03-01", "YYYY-MM-DD"))
  log(moment.tz(moment.utc(), 'America/New_York').utcOffset())
  log(moment.tz(moment.utc(), load_configuration_time(plv8)).utcOffset())

  newYork    = moment.tz("2014-06-01 12:00", "America/New_York");
  losAngeles = newYork.clone().tz("America/Los_Angeles");
  london     = newYork.clone().tz("Europe/London");

  log(newYork.format('ha z'));
  log(losAngeles.format('ha z'));
  log(london.format('ha z'));



exports.log = log
exports.get_default_time = get_default_time
