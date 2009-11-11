require File.dirname(__FILE__) + "/../test_helper.rb"
require "mocha"

class ActsMethodsTest < Test::Unit::TestCase

  # Init 3 AR models to make sure that the updates do not interfiere among
  # them
  class Book < ActiveRecord::Base
    acts_as_solr :offline => proc { |record|
      DaemonizedSolr::Update.register_on( record )
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
  
  def test_schema_has_loaded_correctly
    #ActsAsSolr::ActsMethods.expects(:acts_as_solr).once
    assert_not_nil( Book.send(:configuration))
    assert_not_nil( Book.send(:solr_configuration))
  end

  def test_daemonized_updates_action
    ActsAsSolr::Post.expects(:execute).never
    DaemonizedSolr::Update.expects(:create).with(
      {:action => "update", :instance_id => "ActsMethodsTest::Book:1"}).once
    DaemonizedSolr::Update.expects(:create).with(
      {:action => "update", :instance_id => "ActsMethodsTest::Book:1"}).once
    DaemonizedSolr::Update.expects(:create).with(
      {:action => "delete", :instance_id => "ActsMethodsTest::Book:1"}).once

    b = Book.create!(:title => "im the title!")
    b.title = "2nd title"
    b.save!
    b.destroy
  end

  def test_daemonized_updates_select
    #Stupid test?
    ActsAsSolr::Post.expects(:execute).once
    DaemonizedSolr::Update.expects(:create).once
    #A select does not add any DaemonizedSolr::Update row
    Book.find(:all)
    b = Book.create!(:title => "foo")
    Book.find(:first)
    #The search generates a post.execute but returns nil as there is no book indexed
    assert_equal( nil, Book.find_by_solr("foo"))
  end

  def test_not_daemonized_still_works
    ActsAsSolr::Post.expects(:execute).times(2)
    DaemonizedSolr::Update.expects(:create).never
    Author.create(:name => "Jordi")
  end

  def test_not_solr_still_works
    ActsAsSolr::Post.expects(:execute).never
    DaemonizedSolr::Update.expects(:create).never
    Publisher.create(:name=>"amaNzon")
    assert_equal( 1, Publisher.count )
  end
  
end