#Based on the plugin daemon_generator
class DaemonizedSolrDaemonGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.directory "lib/daemons"
      m.file "daemons", "script/daemons", :chmod => 0755
      m.file "daemonized_solr_processor.rb", "lib/daemons/daemonized_solr_processor.rb", :chmod => 0755
      m.file "daemonized_solr_processor_ctl", "lib/daemons/daemonized_solr_processor_ctl", :chmod => 0755
      m.file "daemons.yml", "config/daemons.yml"
    end
  end
end