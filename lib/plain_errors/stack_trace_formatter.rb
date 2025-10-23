module PlainErrors
  class StackTraceFormatter
    def initialize(backtrace)
      @backtrace = backtrace || []
      @cleaner = setup_cleaner
    end

    def format
      return ["No stack trace available"] if @backtrace.empty?

      # Use Rails BacktraceCleaner for standard path abbreviation if available
      cleaned = @cleaner ? @cleaner.clean(@backtrace, :all) : @backtrace

      max_lines = PlainErrors.configuration.max_stack_trace_lines
      backtrace_to_show = max_lines ? cleaned.first(max_lines) : cleaned

      # Calculate width for index padding based on total number of lines shown
      total_lines = backtrace_to_show.length
      index_width = total_lines.to_s.length

      formatted_trace = backtrace_to_show.map.with_index do |trace_line, index|
        formatted_index = index.to_s.rjust(index_width)
        "#{formatted_index}: #{trace_line}"
      end

      # Add a note if we truncated the stack trace
      if max_lines && cleaned.length > max_lines
        formatted_trace << "(#{cleaned.length - max_lines} more lines omitted)"
      end

      formatted_trace
    end

    private

    def setup_cleaner
      # Use Rails' backtrace cleaner if available
      if defined?(Rails) && Rails.respond_to?(:backtrace_cleaner)
        return Rails.backtrace_cleaner
      end

      # Fall back to ActiveSupport::BacktraceCleaner if available
      return nil unless defined?(ActiveSupport::BacktraceCleaner)

      cleaner = ActiveSupport::BacktraceCleaner.new

      # Add standard filters for cleaner output
      # Strip gem installation paths: /path/to/gems/gem-1.0.0/ -> gems/gem-1.0.0/
      cleaner.add_filter { |line| line.gsub(%r{/.+?/(?:gems|bundler/gems)/}, 'gems/') }

      # Strip application root if configured
      if PlainErrors.configuration.application_root
        root = PlainErrors.configuration.application_root.to_s
        cleaner.add_filter { |line| line.sub(root + '/', './') }
      end

      cleaner
    end
  end
end