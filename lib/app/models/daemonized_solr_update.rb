class DaemonizedSolrUpdate < ActiveRecord::Base
  # Method to register an action on an instance that is indexed
  K_SEP = ":"

  def self.register_on( instance )
    action = ( instance.frozen? ? "delete" : "update" )
    create(
      :action => action,
      :instance_id => instance_id_from(instance) )
    true
  end

  def self.instance_id_from( instance )
    instance.class.name + K_SEP + instance.send(instance.class.primary_key).to_s
  end

  def to_solr_doc
    instance.to_solr_doc
  end

  def instance
    parts = self.instance_id.split(K_SEP)
    key = parts.pop
    klass = parts.join(K_SEP)
    klass.constantize.find(key)
  end
end