# Code that modifies the acts_as_solr method to support :daemonized_updates
# We reopen the class to update it!
module DaemonizedSolr
  module ActsMethods
    include ActsAsSolr::ActsMethods
    
    def daemonized_acts_as_solr( options = {}, solr_options = {})
      cattr_accessor :daemonized_solr
      daemonized_solr = false
      opt = options.dup
      acts_as_solr_orig( options, solr_options )
      if opt[:daemonized_updates]
        # keep config
        daemonized_solr = true
        # overwrite the after_save and after_destroy
        include DaemonizedSolr::InstanceMethods
      end
    end

    alias_method :acts_as_solr_orig, :acts_as_solr
    alias_method :acts_as_solr, :daemonized_acts_as_solr
  end
end
