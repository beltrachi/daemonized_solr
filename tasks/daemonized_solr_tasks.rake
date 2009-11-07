namespace :daemonized_solr do
  desc "Explaining what the task does"
  task :process => :environment do
      DaemonizedSolr::Processor.process_pending_updates
  end
end