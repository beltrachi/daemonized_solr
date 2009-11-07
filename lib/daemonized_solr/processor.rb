module DaemonizedSolr
  # Code to process pending updates
  #
  # Responsabilities:
  class Processor

    include ActsAsSolr::CommonMethods
    include ActsAsSolr::ParserMethods
    include ActsAsSolr::SliceMethods

    attr_reader :lock
    attr_accessor :logger

    def initialize( params )
      raise "Param :lock required" if params[:lock].blank?
      @lock = params[ :lock ].to_i
      raise "Param :lock needs to be int > 0" if @lock < 1
    end

    def process_pending_updates
      reserve_updates!
      process_reserved_updates
      destroy_reserved_updates!
    end

    protected

    def reserve_updates!
      @reserved_updates = nil
      DaemonizedSolrUpdate.update_all( {:lock_id => self.lock},
      " daemonized_solr_updates.lock_id = 0 AND "+
        "daemonized_solr_updates.instance_id NOT IN ( select instance_id FROM "+
        "daemonized_solr_updates where lock_id <> 0 )" )
    end

    # gives the reserved updates sorted by instance_id ASC
    def reserved_updates
      @reserved_updates ||= DaemonizedSolrUpdate.find(:all, 
        :conditions => {:lock_id => self.lock}, :order => "instance_id ASC, id ASC")
    end

    # Process updates reserved by keeping the order in the same instance
    def process_reserved_updates
      return if reserved_updates.size == 0
      update_hash = {}
      delete_hash = {}
      # Clean the repeated items or deleted ones.
      # Avoiding to update an item that will be deleted after and
      # a delete that will be updated after
      reserved_updates.each do |ru|
        case ru.action
        when "update", :update
          update_hash[ru.instance_id] = ru
          #Don't delete something that has been added after
          # Seq: delete X, update X
          # Maybe it has nonsense on AR models 'cause a new instance will have
          # a new id, but anyway it's worthless
          delete_hash.delete(ru.instance_id)
        when "delete", :delete
          delete_hash[ru.instance_id] = ru
          #Delete updates of the instance if exist
          # Seq: update X, delete X
          # will result in delete X only
          update_hash.delete(ru.instance_id)
        end
      end
      #TODO take into account the same conditions as
      # ActsAsSolr::InstanceMethods#solr_save
      # 'cause by now we are indexing all instances. Maybe that filter shoud be
      # done in DaemonizedSolrUpdate#register_on
      if update_hash.size > 0
        execute_updates update_hash
      end
      if delete_hash.size > 0
        execute_deletes delete_hash
      end
      execute_commit
    end
    
    def destroy_reserved_updates!
      reserved_updates.each(&:destroy)
    end

    def execute_updates update_hash
      docs2update = update_hash.values.map(&:to_solr_doc)
      solr_add docs2update
    end

    def execute_deletes delete_hash
      docs2delete = delete_hash.values.map(&:solr_id)
      solr_delete docs2delete
    end

    def execute_commit
      solr_commit
    end

    def logger
      @logger ||= RAILS_DEFAULT_LOGGER
    end
  end
end