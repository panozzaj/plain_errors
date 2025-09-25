module PlainErrors
  class StackTraceFormatter
    def initialize(backtrace)
      @backtrace = backtrace || []
    end

    def format
      return ["No stack trace available"] if @backtrace.empty?

      formatted_trace = @backtrace.map.with_index do |trace_line, index|
        formatted_line = abbreviate_path(trace_line)
        "  #{index}: #{formatted_line}"
      end

      formatted_trace
    end

    private

    def abbreviate_path(trace_line)
      return trace_line unless PlainErrors.configuration.application_root

      root = PlainErrors.configuration.application_root.to_s
      trace_line.sub(root + '/', './')
    end
  end
end