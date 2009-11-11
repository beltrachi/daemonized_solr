require File.dirname(__FILE__) + "/../test_helper.rb"
require "mocha"

#
#   Testing that acts_as_solr without daemonized still works
#
class DaemonizedSolrTest < Test::Unit::TestCase
  load_schema

  class Book < ActiveRecord::Base
    acts_as_solr :offline => proc { |record|
      DaemonizedSolr::Update.register_on( record )
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
    assert_equal 0, DaemonizedSolr::Update.count
    b = Book.create(:title => "barcelona", :description => "desc")
    assert_equal 1, Book.count
    assert_equal 1, DaemonizedSolr::Update.count
    assert_equal 0,Book.find_by_solr("barcelona").total
    p = DaemonizedSolr::Processor.new
    p.process_pending_updates
    assert_equal 0, DaemonizedSolr::Update.count
    assert_equal b, Book.find_by_solr("barcelona").docs.first
  end

  def test_deletes_and_updates_not_intersected
    # New book
    romeo = Book.create(:title => "romeo", :description => "desc")
    assert_equal 1, DaemonizedSolr::Update.count
    assert_equal nil, Book.find_by_solr("romeo").docs.first
    # Add book to solr
    DaemonizedSolr::Processor.new.process_pending_updates
    assert_equal romeo, Book.find_by_solr("romeo").docs.first
    assert_equal 0, DaemonizedSolr::Update.count
    #New 2nd book
    quijote = Book.create(:title => "quijote", :description => "desc")
    assert_equal 1, DaemonizedSolr::Update.count
    assert_equal 2, Book.count
    solr_books = Book.find_by_solr("romeo OR quijote")
    assert_equal 1, solr_books.docs.size
    assert_equal romeo, solr_books.docs.first
    # Remove 1st book
    romeo.destroy
    assert_equal 2, DaemonizedSolr::Update.count
    assert_equal 1, Book.count
    assert_raise(RuntimeError) {
      #Raises exception as romeo is not in DB
      solr_books = Book.find_by_solr("romeo OR quijote")
    }
    solr_books = Book.find_by_solr("quijote")
    assert_equal 0, solr_books.docs.size
    #Updates solr adding 2nd book and removing first
    DaemonizedSolr::Processor.new.process_pending_updates
    assert_equal 0, DaemonizedSolr::Update.count
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

    p = DaemonizedSolr::Processor.new
    p.process_pending_updates

    assert_equal 0, DaemonizedSolr::Update.count
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
    # The DaemonizedSolr::Update will be deleted as it has nonsense to keep it

    romeo = Book.create(:title => "romeo", :description => "desc")
    assert_equal 1, DaemonizedSolr::Update.count
    Book.delete_all( :id => romeo.id )
    
    p = DaemonizedSolr::Processor.new
    p.send(:logger).expects(:warning).once
    p.process_pending_updates

    assert_equal 0, DaemonizedSolr::Update.count
    assert_equal 0, Book.find_by_solr("romeo").docs.size
  end

  def test_compat_with_actsassolr_if_option
    Book.send(:configuration)[:if] = proc {|i| i.title != "noindex" }
    romeo = Book.create(:title => "romeo", :description => "desc")
    noindex = Book.create(:title => "noindex", :description => "desc")
    assert_equal 2, DaemonizedSolr::Update.count
    #The noindex is registered as a delete of the instance to make sure it
    # was not indexed before
    dsu_del = DaemonizedSolr::Update.find(:all,
      :conditions => {:action => "delete" })
    assert_equal 1, dsu_del.size
    assert_equal noindex, dsu_del.first.send(:instance)

    p = DaemonizedSolr::Processor.new
    p.process_pending_updates
    assert_equal 0, Book.find_by_solr("noindex").docs.size

    noindex.destroy
    assert_equal 1, DaemonizedSolr::Update.count

    #weird case when the condition is true but DB has not been updated
    noindex2 = Book.create(:title => "noindex", :description => "desc")
    assert_equal 2, DaemonizedSolr::Update.count
    noindex2.title = "indexnow"
    noindex2.destroy
    assert_equal 3, DaemonizedSolr::Update.count

    dsu_del = DaemonizedSolr::Update.find(:all,
      :conditions => {:action => "delete" })
    assert_equal 3, dsu_del.size
    assert_equal [noindex.solr_id,noindex2.solr_id,noindex2.solr_id],
      dsu_del.map(&:instance_id)
  end

  #TODO test concurrent processors! how?

end