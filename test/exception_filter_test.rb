require_relative "test_helper"

class ExceptionFilterTest < Minitest::Test
  class CustomError < StandardError; end

  def setup
    @config = BugsmithRails::Configuration.new
    @filter = BugsmithRails::ExceptionFilter.new(configuration: @config)
  end

  def test_tracks_all_when_no_allowlist
    assert @filter.track?(CustomError.new("boom"))
  end

  def test_respects_ignored_exceptions
    @config.ignore_exceptions(CustomError)
    refute @filter.track?(CustomError.new("ignore me"))
  end

  def test_respects_allowlist
    @config.track_exceptions(CustomError)
    assert @filter.track?(CustomError.new("track me"))
    refute @filter.track?(RuntimeError.new("do not track"))
  end
end
