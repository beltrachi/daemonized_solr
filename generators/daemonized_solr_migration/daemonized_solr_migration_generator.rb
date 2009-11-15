class DaemonizedSolrMigrationGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.migration_template 'migration.rb', 'db/migrate', :migration_file_name => "daemonized_solr_migration"
    end
  end
end