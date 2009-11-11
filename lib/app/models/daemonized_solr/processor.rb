module DaemonizedSolr
  # Code to process pending updates
  #
  # This class could be a non ActiveRecord but to make sure no lock_id is
  # repeated we use the table PK id field.
  class Processor < ActiveRecord::Base
    set_table_name "daemonized_solr_processors"
    
    include ActsAsSolr::CommonMethods
    include ActsAsSolr::ParserMethods
    include ActsAsSolr::SliceMethods

    attr_reader :lock
    attr_accessor :logger

    #when a new instance is created, its saved on DB too
    def initialize
      super
      save!
      @lock = self.id
    end

    def process_pending_updates
      self.started_at = Time.now
      save!
      reserve_updates!
      process_reserved_updates
      destroy_reserved_updates!
      self.finished_at = Time.now
      save!
    end

    protected

    def reserve_updates!
      @reserved_updates = nil
      DaemonizedSolr::Update.update_all( {:lock_id => self.lock},
      " daemonized_solr_updates.lock_id = 0 AND "+
        "daemonized_solr_updates.instance_id NOT IN ( select instance_id FROM "+
        "daemonized_solr_updates where lock_id <> 0 )" )
    end

    # gives the reserved updates sorted by instance_id ASC
    def reserved_updates
      @reserved_updates ||= DaemonizedSolr::Update.find(:all,
        :conditions => {:lock_id => self.lock},
        :order => "instance_id ASC, id ASC")
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
      # done in DaemonizedSolr::Update#register_on
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
      docs2update = update_hash.values.map do |u|
        begin
          u.to_solr_doc
        rescue ActiveRecord::RecordNotFound
          logger.warning "Record not found to update doc for #{u.inspect}"
        end
      end.compact
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