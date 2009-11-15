namespace :daemonized_solr do
  desc "Process all the pending updates"
  task :process_pending_updates => :environment do
    p = DaemonizedSolr::Processor.new
    p.process_pending_updates
    puts "#{p.updates.size} requests processed"
  end

  desc "Removes all the locks on the pending updates.\n" +
    "  This task is intended to be runned in case a processor processing has failed\n" +
    "  and have not released the updates. USE WITH CAUTION!"
  task :remove_all_locks => :environment do
    DaemonizedSolr::Update.update_all( { :lock_id => 0 } )
    puts "Locks removed from all updates"
  end
end