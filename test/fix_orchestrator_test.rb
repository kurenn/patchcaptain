require_relative "test_helper"

class FixOrchestratorTest < Minitest::Test
  def setup
    @config = PatchCaptain::Configuration.new
    @payload = { exception: { class: "RuntimeError", message: "boom", backtrace: [] } }
    @orchestrator = PatchCaptain::FixOrchestrator.new(@payload, configuration: @config)
  end

  def test_test_gate_fails_when_app_changes_without_tests
    result = @orchestrator.send(:evaluate_test_change_gate, ["app/models/user.rb"])
    assert_equal true, result[:failed]
    assert_equal 1, result[:app_files_changed]
    assert_equal 0, result[:test_files_changed]
  end

  def test_test_gate_passes_when_test_file_present
    result = @orchestrator.send(:evaluate_test_change_gate, ["app/models/user.rb", "spec/models/user_spec.rb"])
    assert_equal false, result[:failed]
    assert_equal 1, result[:app_files_changed]
    assert_equal 1, result[:test_files_changed]
  end
end
