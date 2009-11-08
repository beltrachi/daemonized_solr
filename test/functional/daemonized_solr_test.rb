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
    Book.full_rebuild_solar_index
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

  def test_deletes_and_updates_not_intersected
    # New book
    romeo = Book.create(:title => "romeo", :description => "desc")
    assert_equal 1, DaemonizedSolrUpdate.count
    assert_equal nil, Book.find_by_solr("romeo").docs.first
    # Add book to solr
    DaemonizedSolr::Processor.new(:lock => 1).process_pending_updates
    assert_equal romeo, Book.find_by_solr("romeo").docs.first
    assert_equal 0, DaemonizedSolrUpdate.count
    #New 2nd book
    quijote = Book.create(:title => "quijote", :description => "desc")
    assert_equal 1, DaemonizedSolrUpdate.count
    assert_equal 2, Book.count
    solr_books = Book.find_by_solr("romeo OR quijote")
    assert_equal 1, solr_books.docs.size
    assert_equal romeo, solr_books.docs.first
    # Remove 1st book
    romeo.destroy
    assert_equal 2, DaemonizedSolrUpdate.count
    assert_equal 1, Book.count
    assert_raise(RuntimeError) {
      #Raises exception as romeo is not in DB
      solr_books = Book.find_by_solr("romeo OR quijote")
    }
    solr_books = Book.find_by_solr("quijote")
    assert_equal 0, solr_books.docs.size
    #Updates solr adding 2nd book and removing first
    DaemonizedSolr::Processor.new(:lock => 2).process_pending_updates
    assert_equal 0, DaemonizedSolrUpdate.count
    assert_equal 1, Book.count
    solr_books = Book.find_by_solr("romeo OR quijote")
    assert_equal 1, solr_books.docs.size
    assert_equal quijote, solr_books.docs.first
  end

  def test_updates_and_deletes_intersected
    # New book
    romeo = Book.create(:title => "romeo", :description => "desc")
    quijote = Book.create(:title => "quijote", :description => "desc")
    ender = Book.create(:title => "the ender's game", :description => "desc")
    romeo.title = "romeo and gilette"
    romeo.save!
    romeo.destroy
    quijote.description = "a crazy man!"
    quijote.save!
    quijote.description = "epic book"
    quijote.save!

    p = DaemonizedSolr::Processor.new(:lock => 1)
    p.process_pending_updates

    assert_equal 0, DaemonizedSolrUpdate.count
    assert_equal 0, Book.find_by_solr("gilette OR romeo OR crazy OR man").docs.size
    ["quijote", "ender", "game", "epic"].each do |q|
      assert_equal 1, Book.find_by_solr( q ).docs.size
    end
    assert_equal 2, Book.find_by_solr( "desc OR epic" ).docs.size
    assert_equal 2, Book.count
  end

  def test_disappeared_instance
    # test what happens when an instance has to be updated but it does not
    # exist in the database
    #
    # The ActiveRecord::RecordNotFound will be captured and logged a warning
    # as the non existance of an instance can happen in some event sequences and
    # is not recoverable.
    #
    # Case:
    #   Scenario : DSUpdates table: [ Update Book:1 ]
    #   Sequence:
    #     Processor reserves the update and is rescheduled
    #     The instance 1 is destroyed
    #     The processor generates docs for reserved updates and raises the
    #       exception
    #     The exception is rescued and logged as a warning
    #
    # The DaemonizedSolrUpdate will be deleted as it has nonsense to keep it

    romeo = Book.create(:title => "romeo", :description => "desc")
    assert_equal 1, DaemonizedSolrUpdate.count
    Book.delete_all( :id => romeo.id )
    
    p = DaemonizedSolr::Processor.new(:lock => 1)
    p.send(:logger).expects(:warning).once
    p.process_pending_updates

    assert_equal 0, DaemonizedSolrUpdate.count
    assert_equal 0, Book.find_by_solr("romeo").docs.size
  end

  #TODO test concurrent processors! how?

end