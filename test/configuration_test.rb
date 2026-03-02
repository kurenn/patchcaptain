require_relative "test_helper"

class ConfigurationTest < Minitest::Test
  def test_flow_mode_normalization
    config = BugsmithRails::Configuration.new
    config.flow_mode = :remote
    assert_equal :github_api, config.flow_mode

    config.flow_mode = :local
    assert_equal :github_api, config.flow_mode
  end
end
