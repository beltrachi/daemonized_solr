class SolrUpdate < ActiveRecord::Base
  # Method to register an action on an instance that is indexed
  def self.register_on( instance )
    action = ( instance.frozen? ? "delete" : "update" )
    SolrUpdate.create(
      :action => action,
      :instance_id => instance_id_from(instance) )
    true
  end

  def self.instance_id_from( instance )
    instance.class.name + "@" + instance.id.to_s
  end
end