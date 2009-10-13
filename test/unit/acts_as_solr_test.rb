require File.dirname(__FILE__) + "/../test_helper.rb"
require "mocha"

#Testing that acts_as_solr still works
class ActsAsSolrTest < Test::Unit::TestCase
  load_schema

  class Book < ActiveRecord::Base
    acts_as_solr
  end

  class SolrUpdate < ActiveRecord::Base
  end

  def test_schema_has_loaded_correctly
    #ActsAsSolr::ActsMethods.expects(:acts_as_solr).once
    assert_not_nil( Book.send(:configuration))
    assert_not_nil( Book.send(:solr_configuration))
  end

  def test_create_posts_to_solr
    ActsAsSolr::Post.expects(:execute).times(2) #doc post and commit
    SolrUpdate.expects(:new).with(
      {:action => "update", :instance_id => "Book:1"}).never
    Book.create(:title => "i'm the title!")
    assert_equal( 0, SolrUpdate.count )
  end

  



end