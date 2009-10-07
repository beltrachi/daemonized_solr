ActiveRecord::Schema.define(:version => 0) do
  create_table :books, :force => true do |t|
    t.string :title
    t.string :description
    t.datetime :printed_at
  end
end