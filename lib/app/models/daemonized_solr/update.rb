module DaemonizedSolr
  class Update < ActiveRecord::Base
    set_table_name "daemonized_solr_updates"

    K_SEP = ":"

    # Method to register an action on an instance that is indexed
    def self.register_on( instance )
      action = if instance.frozen? || !instance.send(:evaluate_condition, :if, instance)
        "delete"
      else
        "update"
      end
      create(
        :action => action,
        :instance_id => instance_id_from(instance) )
      true
    end

    def to_solr_doc
      instance.to_solr_doc
    end

    def solr_id
      instance(true).solr_id
    end

    protected
    def self.instance_id_from( instance )
      instance.class.name + K_SEP + instance.send(instance.class.primary_key).to_s
    end

    # The param "simulated" allows to get an instance solr_id from a destroyed
    # instance
    def instance( simulated = false )
      parts = self.instance_id.split(K_SEP)
      key = parts.pop
      klass = parts.join(K_SEP).constantize
      inst = nil
      if simulated
        inst = klass.new
        inst.send( klass.primary_key.to_s + "=", key)
      else
        inst = klass.find(key)
      end
      inst
    end

  end
end