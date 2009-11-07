require File.dirname(__FILE__) + "/../test_helper.rb"
require "mocha"

class ProcessorTest < Test::Unit::TestCase

  # Init 3 AR models to make sure that the updates do not interfiere among
  # them
  class Book < ActiveRecord::Base
    acts_as_solr :offline => proc { |record|
      DaemonizedSolrUpdate.register_on( record )
    }
  end

  class Author < ActiveRecord::Base
    acts_as_solr
  end

  class Publisher < ActiveRecord::Base
  end

  def setup
    super
    load_schema
  end

  def test_create
    ["","a", nil].each do |key|
      ex = nil
      begin
        DaemonizedSolr::Processor.new( :lock => key )
      rescue
        ex = $!
      end
      assert_equal( RuntimeError, ex.class)
    end
    ["1", 11, 11.223].each do |key|
      DaemonizedSolr::Processor.new( :lock => key)
    end
  end
  
  def test_process_pending_updates
    p = DaemonizedSolr::Processor.new( :lock => 1 )
    p.expects(:reserve_updates!).once
    p.expects(:reserved_updates).times(2).returns([])
    p.process_pending_updates
  end

  def test_do_reservations
    p = DaemonizedSolr::Processor.new( :lock => 1 )
    reserved_updates = [{:instance_id => "Book:1"},{:instance_id => "Book:2"}]
    DaemonizedSolrUpdate.expects(:update_all).with(
      {:lock_id => 1},
        " daemonized_solr_updates.lock_id = 0 AND "+
          "daemonized_solr_updates.instance_id NOT IN ( select instance_id FROM "+
          "daemonized_solr_updates where lock_id <> 0 )"
    ).once
    #Prepare response
    rus = reserved_updates.map do |ru|
      nru = DaemonizedSolrUpdate.new(ru.merge(:lock_id => 1,:action => "update"))
      nru.expects(:destroy).once #That update will be destroyed!
      nru
    end
    DaemonizedSolrUpdate.expects(:find).with(
      :all, :conditions => {:lock_id => 1},:order => "instance_id ASC, id ASC").returns( rus )
    DaemonizedSolrUpdate.any_instance.stubs(:to_solr_doc).returns(Solr::Document.new)
    ActsAsSolr::Post.expects(:execute).times(2)

    p.process_pending_updates
  end

end
