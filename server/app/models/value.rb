class Value < ApplicationRecord
  self.primary_key = 'name'

  SECOND = 'second'
  MINUTE = 'minute'
  HOUR   = 'hour'
  DAY    = 'day'
  WEEK   = 'week'
  MONTH  = 'month'
  YEAR   = 'year'

  TIME_UNITS = {
    SECOND => 1,
    MINUTE => 1 * 60,
    HOUR   => 1 * 60 * 60,
    DAY    => 1 * 60 * 60 * 24,
    WEEK   => 1 * 60 * 60 * 24 * 7,
    MONTH  => 1 * 60 * 60 * 24 * 7 * 30,
    YEAR   => 1 * 60 * 60 * 24 * 7 * 30 * 52
  }

  TTL = {
    SECOND => TIME_UNITS[HOUR],
    MINUTE => TIME_UNITS[DAY],
    HOUR   => TIME_UNITS[WEEK],
    DAY    => TIME_UNITS[MONTH],
    WEEK   => TIME_UNITS[YEAR]
  }

  NAME = 'name'
  TYPES = ['cpu', 'ram'].to_set

  def save_values(params)
    name = params[NAME]
  end



  #{"name"=>"home", "cpu"=>["1495977848;33.86"], "ram"=>["1495977848;84.67"]}



  def insert(type, time_unit, timestamp, value)
    key = get_hash_name(type, time_unit)
    field = round_timestamp(timestamp, time_unit)
    RedisConnection.hset(key, field, value)
  end

private

  def get_hash_name(type, time_unit)
    "value:#{self.name}:#{type}:#{time_unit}"
  end

  def round_timestamp(timestamp, time_unit)
    ((timestamp.to_f / TIME_UNITS[time_unit]).floor * timestamp).to_i
  end

end
