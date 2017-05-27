require 'rubygems'
require 'bundler/setup'
require 'concurrent'
require 'httparty'


module Monik
  MAX_PERCENT = 100.0
  RAM_MESUAR_COUNT = 3

  class Client
    include Concurrent::Async

    attr_accessor :cpu_values, :ram_values

    @active = true

    def self.active?
      @active
    end

    def self.active=(active)
      @active = active
    end

    def initialize(api_url, name, period = 15)
      @api_url = api_url
      @name = name
      @period = period
      @cpu_values = Queue.new
      @ram_values = Queue.new
    end

    def run
      self.async.collect_cpu
      self.async.collect_ram

      while Client.active?
        puts 'send data'
        HTTParty.post(@api_url, {'a' => 1})
        sleep @period
      end
    end

    def collect_cpu
      loop do
        @cpu_values << cpu_usage
      end
    end

    def collect_ram
      loop do
        @cpu_values << ram_usage
      end
    end

  private

    def cpu_usage
      output = `mpstat #{@period} 1`
      /(?<idle>[\d\,]+)\Z/ =~ output
      available_percent = idle.gsub(',', '.').to_f
      [timestamp, MAX_PERCENT - available_percent]
    end

    def ram_usage
      available_percents = (0...RAM_MESUAR_COUNT).map do
        sleep(@period / RAM_MESUAR_COUNT)
        meminfo = File.read('/proc/meminfo')
        /MemTotal:\s*(?<mem_total>\d+)/ =~ meminfo
        /MemAvailable:\s*(?<mem_available>\d+)/ =~ meminfo
        (mem_available.to_f / mem_total.to_f).round(2) * 100
      end
      available_percent = (available_percents.inject(&:+) / available_percents.count).round(2)
      [timestamp, MAX_PERCENT - available_percent]
    end

    def timestamp
      Time.now.utc.to_i
    end
  end
end

Signal.trap("INT") {
  puts 'Shut down'
  Monik::Client.active = false
}

@monik = Monik::Client.new('http://127.0.0.1:3000/register_values', ENV['HOSTNAME'] || 'home')
@monik.run
