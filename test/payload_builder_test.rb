require_relative "test_helper"

class PayloadBuilderTest < Minitest::Test
  def test_uses_full_backtrace_when_limit_is_nil
    config = PatchCaptain::Configuration.new
    config.max_backtrace_lines = nil

    exception = RuntimeError.new("boom")
    exception.set_backtrace(%w[line1 line2 line3])

    payload = PatchCaptain::PayloadBuilder.new(exception, configuration: config).build
    assert_equal %w[line1 line2 line3], payload.dig(:exception, :backtrace)
  end
end
