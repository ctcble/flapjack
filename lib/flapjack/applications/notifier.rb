#!/usr/bin/env ruby

require 'log4r'
require 'log4r/outputter/syslogoutputter'
require 'flapjack/patches'
require 'flapjack/filters/ok'
require 'flapjack/filters/acknowledged'

module Flapjack
  class Notifier
    # Boots the notifier.
    def self.run(options={})
      self.new(options)
    end

    attr_accessor :log

    def initialize(options={})
      @options     = options
      @persistence = ::Redis.new
      @events      = Flapjack::Events.new

      @log = Log4r::Logger.new("notifier")
      @log.add(Log4r::StdoutOutputter.new("notifier"))
      @log.add(Log4r::SyslogOutputter.new("notifier"))


      options = { :log => @log, :persistence => @persistence }
      @filters = []
      @filters << Flapjack::Filters::Ok.new(options)
      @filters << Flapjack::Filters::Acknowledged.new(options)
    end

    def process_result
      @log.info("Waiting for event...")
      event = @events.next

      @log.debug("#{@events.size} events waiting on the queue")

      #@log.info("Storing event.")
      #@persistence.save(event)

      block = @filters.find {|filter| filter.block?(event) }
      if not block
        @log.info("Sending notifications for event #{event.host};#{event.service}")
      else
        @log.info("Not sending notifications for event #{event.host};#{event.service} because the #{block.name} filter blocked")
      end
    end

    def main
      @log.info("Booting main loop.")
      loop do
        process_result
      end
    end
  end
end
