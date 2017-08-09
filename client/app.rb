require 'rubygems'
require 'bundler/setup'
require 'concurrent'
require 'httparty'
require 'pry'


module Monik
  MAX_PERCENT = 100.0
  RAM_MESUAR_COUNT = 3
  SEND_DATA_DELAY = 300

  class Client
    include Concurrent::Async

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
      puts 'Client start working...'
      Concurrent::Future.execute { collect_cpu }
      Concurrent::Future.execute { collect_ram }

      while Client.active?
        puts "Sleep for #{SEND_DATA_DELAY} sec"
        sleep 30
        send_data
      end

      puts 'Send rest of data...'
      send_data
      puts 'Bye bye...'
    end

    def collect_cpu
      loop do
        @cpu_values << cpu_usage
      end
    end

    def collect_ram
      loop do
        @ram_values << ram_usage
      end
    end

    def send_data
      puts "Start send data"
      puts "API URL: #{@api_url}"
      body = get_post_body
      puts "Body: #{body[:values][:cpu].count} cpu, #{body[:values][:ram].count} ram values"
      begin
        response = HTTParty.post(@api_url, { body: body })
        puts "Response: code #{response.code}, status #{response.message}"
      rescue Errno::ECONNREFUSED => e
        puts 'Server does not respond'
        puts e.message
        puts 'Save not sended data'
        body[:values][:cpu].each { |v| @cpu_values << v }
        body[:values][:ram].each { |v| @ram_values << v }
      end
    end

  private

    def cpu_usage
      output = `mpstat #{@period} 1`
      /(?<idle>[\d\,]+)\Z/ =~ output
      available_percent = idle.gsub(',', '.').to_f
      "#{timestamp};#{(MAX_PERCENT - available_percent).round(2)}"
    end

    def ram_usage
      available_percents = (0...RAM_MESUAR_COUNT).map do
        sleep(@period / RAM_MESUAR_COUNT)
        meminfo = File.read('/proc/meminfo')
        /MemTotal:\s*(?<mem_total>\d+)/ =~ meminfo
        /MemAvailable:\s*(?<mem_available>\d+)/ =~ meminfo
        (mem_available.to_f / mem_total.to_f).round(2) * 100
      end
      available_percent = available_percents.inject(&:+) / available_percents.count
      "#{timestamp};#{(MAX_PERCENT - available_percent).round(2)}"
    end

    def get_post_body
      body = {
        name: @name,
        values: {
          cpu: [],
          ram: []
        }
      }
      body[:values][:cpu] << @cpu_values.pop until @cpu_values.empty?
      body[:values][:ram] << @ram_values.pop until @ram_values.empty?
      body
    end

    def timestamp
      Time.now.utc.to_i
    end
  end
end

Signal.trap("INT") {
  puts 'Gracefully shut down'
  Monik::Client.active = false
}

Monik::Client.new('http://127.0.0.1:3000/values', ENV['HOSTNAME'] || 'home').run
