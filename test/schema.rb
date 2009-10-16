ActiveRecord::Schema.define(:version => 0) do
  create_table :books, :force => true do |t|
    t.string :title
    t.string :description
    t.datetime :printed_at
  end
  create_table :authors, :force => true do |t|
    t.string :name
  end
  create_table :publishers, :force => true do |t|
    t.string :name
  end
  create_table :daemonized_solr_solr_updates, :force => true do |t|
    t.string :action, :null => false
    t.string :instance_id, :null => false
    t.integer :tread_id
  end
end