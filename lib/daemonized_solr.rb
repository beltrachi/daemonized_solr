# DaemonizedSolr
module DaemonizedSolr; end

%w{ models }.each do |dir| 
  path = File.join(File.dirname(__FILE__), 'app', dir)
  $LOAD_PATH << path
  ActiveSupport::Dependencies.load_paths << path
  ActiveSupport::Dependencies.load_once_paths.delete(path)
end

require "acts_as_solr"
require "daemonized_solr/acts_methods"
ActiveRecord::Base.extend DaemonizedSolr::ActsMethods
