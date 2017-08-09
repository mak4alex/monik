RedisConnection = Redis::Namespace.new("monik:#{ENV['RAILS_ENV']}", :redis => Redis.new)
