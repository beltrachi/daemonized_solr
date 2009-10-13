#
require "acts_as_solr"
module DaemonizedSolr
  module InstanceMethods
    include ActsAsSolr::InstanceMethods
    alias_method :solr_save_orig, :solr_save
    alias_method :solr_destroy_orig, :solr_destroy

    def solr_save
      SolrUpdate.create(:action => "update", :instance_id => solr_id )
      true
    end

    def solr_destroy
      SolrUpdate.create(:action => "delete", :instance_id => solr_id )
      true
    end
  end
end
