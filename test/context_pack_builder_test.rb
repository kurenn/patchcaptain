require_relative "test_helper"
require "fileutils"

class ContextPackBuilderTest < Minitest::Test
  def test_build_includes_skill_and_backtrace_snippet
    test_file = File.join(Dir.pwd, "tmp", "bugsmith_context_builder_test.rb")
    FileUtils.mkdir_p(File.dirname(test_file))
    File.write(test_file, "line1\nline2\nline3\nline4\n")

    config = BugsmithRails::Configuration.new
    config.skill_text = "Always add regression tests."
    config.context_files = []
    config.max_prompt_context_chars = 10_000
    config.max_backtrace_files = 2
    config.backtrace_context_radius = 1

    payload = {
      exception: {
        class: "RuntimeError",
        message: "boom",
        backtrace: ["#{test_file}:3:in `call'"]
      }
    }

    result = BugsmithRails::ContextPackBuilder.new(payload, configuration: config).build
    assert_includes result, "Repair Skill Instructions"
    assert_includes result, "Backtrace Snippet"
    assert_includes result, "line3"
  ensure
    File.delete(test_file) if File.exist?(test_file)
  end

  def test_build_reads_files_from_context_directory_targets
    root = Dir.pwd
    dir = File.join(root, "tmp", "bugsmith_context_dir")
    file = File.join(dir, "instructions.md")
    FileUtils.mkdir_p(dir)
    File.write(file, "Use service objects for side effects.\n")

    config = BugsmithRails::Configuration.new
    config.context_files = [dir]
    config.max_context_files = 10
    config.max_context_file_bytes = 10_000
    config.include_backtrace_file_snippets = false

    payload = { exception: { class: "RuntimeError", message: "boom", backtrace: [] } }
    result = BugsmithRails::ContextPackBuilder.new(payload, configuration: config).build

    assert_includes result, "Project File: tmp/bugsmith_context_dir/instructions.md"
    assert_includes result, "Use service objects for side effects."
  ensure
    FileUtils.rm_rf(dir) if dir && Dir.exist?(dir)
  end
end
