require File.dirname(__FILE__) + "/../test_helper.rb"
require "mocha"

#
#   Testing that acts_as_solr without daemonized still works
#
class DaemonizedSolrTest < Test::Unit::TestCase
  load_schema

  class Book < ActiveRecord::Base
    acts_as_solr :offline => proc { |record|
      DaemonizedSolrUpdate.register_on( record )
    }
  end

  class Author < ActiveRecord::Base
  end

  def setup
    super
    load_schema
  end

  def test_simple
    assert_equal 0, Book.count
    assert_equal 0, DaemonizedSolrUpdate.count
    b = Book.create(:title => "barcelona", :description => "desc")
    assert_equal 1, Book.count
    assert_equal 1, DaemonizedSolrUpdate.count
    assert_equal 0,Book.find_by_solr("barcelona").total
    p = DaemonizedSolr::Processor.new(:lock=> 1)
    p.process_pending_updates
    assert_equal 0, DaemonizedSolrUpdate.count
    assert_equal b, Book.find_by_solr("barcelona").docs.first
  end
end