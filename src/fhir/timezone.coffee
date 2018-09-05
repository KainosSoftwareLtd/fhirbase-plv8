utils = require('../core/utils')
sql = require('../honey')

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

get_default_time = (plv8)->
  log("Get default time")

  res = utils.exec plv8,
    select: sql.raw('timezone')
    from: sql.q("timezone_configuration")

  log(res)

  row = res[0]
  if typeof row == "object"
    row = row.timezone
  
  log(row)

  return row

exports.log = log
exports.get_default_time = get_default_time
