require_relative "test_helper"

class ConfigurationTest < Minitest::Test
  def teardown
    ENV.delete("PATCHCAPTAIN_REQUIRE_TEST_CHANGES_FOR_APP_CHANGES")
    ENV.delete("PATCHCAPTAIN_BLOCK_PR_ON_MISSING_TESTS")
  end

  def test_flow_mode_normalization
    config = PatchCaptain::Configuration.new
    config.flow_mode = :remote
    assert_equal :github_api, config.flow_mode

    config.flow_mode = :local
    assert_equal :github_api, config.flow_mode
  end

  def test_default_context_files
    config = PatchCaptain::Configuration.new
    assert_includes config.context_files, "README.md"
    assert_includes config.context_files, "AGENTS.md"
    assert_includes config.context_files, ".agent/workflows"
    assert_includes config.context_files, ".github/instructions"
  end

  def test_env_bool_overrides_for_test_gate
    ENV["PATCHCAPTAIN_REQUIRE_TEST_CHANGES_FOR_APP_CHANGES"] = "false"
    ENV["PATCHCAPTAIN_BLOCK_PR_ON_MISSING_TESTS"] = "true"
    config = PatchCaptain::Configuration.new
    assert_equal false, config.require_test_changes_for_app_changes
    assert_equal true, config.block_pr_on_missing_tests
  end
end
