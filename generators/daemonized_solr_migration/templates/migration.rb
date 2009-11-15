class DaemonizedSolrMigration < ActiveRecord::Migration
  def self.up
    create_table :daemonized_solr_updates, :force => true do |t|
      t.string :action, :null => false
      t.string :instance_id, :null => false
      t.integer :lock_id, :default => 0, :null => false
    end
    create_table :daemonized_solr_processors, :force => true do |t|
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
  end

  def self.down
    drop_table :daemonized_solr_updates
    drop_table :daemonized_solr_processors
  end
end
