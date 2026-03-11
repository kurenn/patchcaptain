module PatchCaptain
  class ContextPackBuilder
    def initialize(payload, configuration: PatchCaptain.configuration)
      @payload = payload
      @configuration = configuration
      @project_root = Pathname(@configuration.repository_path.to_s)
    end

    def build
      max_chars = @configuration.max_prompt_context_chars.to_i
      max_chars = 20_000 if max_chars <= 0

      sections = []
      append_skill_section(sections)
      append_context_files(sections)
      append_backtrace_snippets(sections)
      truncate_sections(sections, max_chars)
    end

    private

    def append_skill_section(sections)
      text = @configuration.skill_text.to_s
      if text.strip.empty? && @configuration.skill_path.present?
        text = safe_read_text(resolve_path(@configuration.skill_path))
      end
      return if text.to_s.strip.empty?

      sections << section("Repair Skill Instructions", text)
    end

    def append_context_files(sections)
      context_targets.each do |full_path|
        body = safe_read_text(full_path, @configuration.max_context_file_bytes)
        next if body.strip.empty?

        relative = relative_path(full_path)
        sections << section("Project File: #{relative}", body)
      end
    end

    def append_backtrace_snippets(sections)
      return unless @configuration.include_backtrace_file_snippets

      files = extract_backtrace_file_targets
      seen_files = Set.new

      # First, include FULL contents of unique app files from the backtrace.
      # This ensures the AI has the complete file when generating updates,
      # preventing it from omitting existing code.
      files.first(@configuration.max_backtrace_files).each do |target|
        full_path = target[:path]
        next unless full_path.file?
        next if seen_files.include?(full_path.to_s)

        seen_files.add(full_path.to_s)

        text = safe_read_text(full_path)
        next if text.strip.empty?

        relative = relative_path(full_path)
        sections << section("Full Source File (preserve all code when updating): #{relative}", text)
      end
    end

    def extract_backtrace_file_targets
      seen = {}
      Array(@payload.dig(:exception, :backtrace)).filter_map do |entry|
        parsed = parse_backtrace_entry(entry)
        next unless parsed
        key = "#{parsed[:path]}:#{parsed[:line]}"
        next if seen[key]

        seen[key] = true
        parsed
      end
    end

    def parse_backtrace_entry(entry)
      match = entry.to_s.match(/\A(.+?):(\d+)(?::in `.*')?\z/)
      return unless match

      path = Pathname(match[1]).expand_path
      return unless path.to_s.start_with?(@project_root.to_s)
      return if path.to_s.include?("/gems/")

      { path: path, line: match[2].to_i }
    rescue ArgumentError
      nil
    end

    def resolve_path(path)
      candidate = Pathname(path.to_s)
      candidate = @project_root.join(candidate) unless candidate.absolute?
      candidate.expand_path
    rescue ArgumentError
      @project_root
    end

    def line_window(text, line_number, radius)
      lines = text.lines
      return text if lines.empty?

      line_index = [line_number - 1, 0].max
      start_idx = [line_index - radius, 0].max
      end_idx = [line_index + radius, lines.length - 1].min

      visible = lines[start_idx..end_idx] || []
      visible.map.with_index(start_idx + 1) { |line, i| format("%5d: %s", i, line) }.join
    end

    def safe_read_text(path, max_bytes = nil)
      content = if max_bytes.to_i > 0
                  File.open(path.to_s, "rb") { |f| f.read(max_bytes) }
                else
                  File.binread(path.to_s)
                end
      content.encode("UTF-8", invalid: :replace, undef: :replace)
    rescue
      ""
    end

    def relative_path(path)
      path.relative_path_from(@project_root).to_s
    rescue
      path.to_s
    end

    def section(title, body)
      <<~SECTION
        ## #{title}
        #{body}
      SECTION
    end

    def truncate_sections(sections, max_chars)
      return "" if sections.empty?

      remaining = max_chars
      output = []
      sections.each do |section_text|
        break if remaining <= 0
        next if section_text.strip.empty?

        chunk = section_text[0, remaining]
        output << chunk
        remaining -= chunk.length
      end
      output.join("\n")
    end
  end
end
    def context_targets
      paths = Array(@configuration.context_files).filter_map do |entry|
        full_path = resolve_path(entry)
        next unless full_path.exist?

        if full_path.directory?
          directory_files(full_path)
        elsif full_path.file?
          [full_path]
        end
      end.flatten

      unique_paths = paths.map(&:to_s).uniq.map { |p| Pathname(p) }
      unique_paths.first(@configuration.max_context_files)
    end

    def directory_files(dir_path)
      Dir.glob(File.join(dir_path.to_s, "**", "*"))
         .sort
         .map { |p| Pathname(p) }
         .select(&:file?)
    rescue
      []
    end
