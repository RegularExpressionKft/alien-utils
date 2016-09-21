AlienLogger = require '../logger'

logger = AlienLogger.init 'master', 'dev'
logger.info 'Hello'

logger.level = 'info'
logger.debug 'no show'
logger.info 'yes please'

object = (new AlienLogger 'object').decorate
  dumpMe:
    x: 12.5
    y: -1
object.debug('object.dumpMe', object.dumpMe)
      .info 'hello'
