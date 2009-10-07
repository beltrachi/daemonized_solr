require File.dirname(__FILE__) + "/../test_helper.rb"

class ActsMethodsTest < Test::Unit::TestCase
  load_schema

  class Book < ActiveRecord::Base
  end

  def test_schema_has_loaded_correctly
  end

end