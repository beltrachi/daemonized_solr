require File.dirname(__FILE__) + "/../test_helper.rb"
require "mocha"

class ActsMethodsTest < Test::Unit::TestCase
  load_schema

  class Book < ActiveRecord::Base
    acts_as_solr :daemonized_updates => true
  end

  def test_schema_has_loaded_correctly
    #ActsAsSolr::ActsMethods.expects(:acts_as_solr).once
    assert_not_nil( Book.send(:configuration))
    assert_not_nil( Book.send(:solr_configuration))
  end

  def test_daemonized_updates_action
    ActsAsSolr::Post.expects(:execute).never
    SolrUpdate.expects(:create).with(
      {:action => "update", :instance_id => "ActsMethodsTest::Book:2"}).once
    SolrUpdate.expects(:create).with(
      {:action => "update", :instance_id => "ActsMethodsTest::Book:2"}).once
    SolrUpdate.expects(:create).with(
      {:action => "delete", :instance_id => "ActsMethodsTest::Book:2"}).once

    b = Book.create!(:title => "im the title!")
    b.title = "2nd title"
    b.save!
    b.destroy
  end
end