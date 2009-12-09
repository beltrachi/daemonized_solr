module DaemonizedSolr
  # Class to process pending updates
  #
  # This class could be a non ActiveRecord but to make easy that no lock_id is
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
      @error = false #flag to not allow to call processor again after a failure.
    end

    # Process pending updates taking into account all the restrictions on the
    # reservation to allow concurrent processors.
    def process_pending_updates
      raise "Processor has failed. Don't reuse it and check what has happened!" if @error
      begin
        self.started_at = Time.now
        save!
        reserve_updates!
        process_reserved_updates
        destroy_reserved_updates!
        self.finished_at = Time.now
        save!
      rescue Exception
        @error = $!
        begin
        logger.error("Processor is in error state. It cannot be used anymore " +
            "and has to be checked")
        rescue
        end
        raise @error
      end
    end

    # public accessor for updates being locked in this processor
    def updates
      @reserved_updates.dup
    end

    protected

    def reserve_updates!
      logger.debug("Reserving updates with lock #{self.lock}")
      @reserved_updates = nil #Forget old reserved updates

      #This query is atomic to allow more than one processor run at a time.
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
      logger.info("Reserved #{reserved_updates.size} updates for the processor #{self.lock}")
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
      logger.debug("Found #{update_hash.size} updates and " + 
          "#{delete_hash.size} deletes to execute.")
      if update_hash.size > 0
        execute_updates update_hash
      end
      if delete_hash.size > 0
        execute_deletes delete_hash
      end
      execute_commit
    end
    
    def destroy_reserved_updates!
      logger.info("Destroying the #{reserved_updates.size} processed updates.")
      reserved_updates.each(&:destroy)
    end

    def execute_updates update_hash
      docs2update = update_hash.values.map do |u|
        begin
          u.to_solr_doc
        rescue ActiveRecord::RecordNotFound
          # This can happen in some concurrent cases and is not big deal.
          # Can happen when a update has been reserved with a lock, and
          # just after that, the instance has been deleted.
          logger.warning "Record not found to update doc for #{u.inspect}." 
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