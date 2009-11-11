require File.dirname(__FILE__) + "/../test_helper.rb"
require "mocha"

#
#   Testing that acts_as_solr without daemonized still works
#
class ActsAsSolrTest < Test::Unit::TestCase
  load_schema

  class Book < ActiveRecord::Base
    acts_as_solr
  end

  class Author < ActiveRecord::Base
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

  def test_create_posts_to_solr
    ActsAsSolr::Post.expects(:execute).times(2) #doc post and commit
    DaemonizedSolr::Update.expects(:create).never
    Book.create!(:title => "i'm the title!")
  end

  def test_search_on_solr
    ActsAsSolr::Post.expects(:execute).times(3)
    DaemonizedSolr::Update.expects(:create).never
    Book.create(:title => "i'm the title!")
    Book.find_by_solr("title")
  end

  def test_author_works
    ActsAsSolr::Post.expects(:execute).never
    DaemonizedSolr::Update.expects(:create).never
    Author.create(:name => "andrew")
  end

end