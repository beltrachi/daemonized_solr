require File.dirname(__FILE__) + "/../test_helper.rb"
require "mocha"

class ActsMethodsTest < Test::Unit::TestCase

  class Book < ActiveRecord::Base
    acts_as_solr :daemonized_updates => true
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
    SolrUpdate.expects(:create).with(
      {:action => "update", :instance_id => "ActsMethodsTest::Book:1"}).once
    SolrUpdate.expects(:create).with(
      {:action => "update", :instance_id => "ActsMethodsTest::Book:1"}).once
    SolrUpdate.expects(:create).with(
      {:action => "delete", :instance_id => "ActsMethodsTest::Book:1"}).once

    b = Book.create!(:title => "im the title!")
    b.title = "2nd title"
    b.save!
    b.destroy
  end

  def test_daemonized_updates_select
    #Stupid test?
    ActsAsSolr::Post.expects(:execute).once
    SolrUpdate.expects(:create).once
    #A select does not add any SolrUpdate row
    Book.find(:all)
    b = Book.create!(:title => "foo")
    Book.find(:first)
    #The search generates a post.execute but returns nil as there is no book indexed
    assert_equal( nil, Book.find_by_solr("foo"))
  end
end