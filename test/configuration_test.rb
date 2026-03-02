require_relative "test_helper"

class ConfigurationTest < Minitest::Test
  def test_flow_mode_normalization
    config = BugsmithRails::Configuration.new
    config.flow_mode = :remote
    assert_equal :github_api, config.flow_mode

    config.flow_mode = :local
    assert_equal :github_api, config.flow_mode
  end

  def test_default_context_files
    config = BugsmithRails::Configuration.new
    assert_includes config.context_files, "README.md"
    assert_includes config.context_files, "AGENTS.md"
    assert_includes config.context_files, ".agent/workflows"
    assert_includes config.context_files, ".github/instructions"
  end
end
