#!/usr/bin/env ruby

# You might want to change this
ENV["RAILS_ENV"] ||= "production"

require File.dirname(__FILE__) + "/../../config/environment"

$running = true
Signal.trap("TERM") do 
  $running = false
end

p = DaemonizedSolr::Processor.new

while($running) do
  begin
    ActiveRecord::Base.logger.info "DaemonizedSolr::Processor daemon is still running at #{Time.now}.\n"
    p.process_pending_updates
    ActiveRecord::Base.logger.info "DaemonizedSolr::Processor: #{p.updates.size} requests processed."
    sleep 10
  rescue Exception => e
    ActiveRecord::Base.logger.error "DaemonizedSolr::Processor has finished with an exception: #{e}"
    raise
  end
end