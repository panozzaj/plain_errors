module PlainErrors
  class Formatter
    def initialize(exception, request = nil)
      @exception = exception
      @request = request
      @config = PlainErrors.configuration
    end

    def format
      output = []

      output << "ERROR: #{@exception.class}: #{@exception.message}"
      output << ""

      if @config.show_code_snippets && source_location
        output << code_snippet_section
        output << ""
      end

      output << stack_trace_section

      if @config.show_request_info && @request
        output << ""
        output << request_info_section
      end

      if @config.show_variables
        output << ""
        output << variables_section
      end

      output.join("\n")
    end

    private

    def source_location
      return nil unless @exception.respond_to?(:backtrace) && @exception.backtrace

      first_trace = @exception.backtrace.first
      return nil unless first_trace

      match = first_trace.match(/^(.+):(\d+)/)
      return nil unless match

      { file: match[1], line: match[2].to_i }
    end

    def code_snippet_section
      location = source_location
      return "Code snippet unavailable" unless location

      extractor = CodeExtractor.new(location[:file], location[:line])
      snippet = extractor.extract(@config.code_lines_context)

      output = ["CODE SNIPPET:"]
      output << "File: #{abbreviate_path(location[:file])}:#{location[:line]}"
      output << ""
      output.concat(snippet)
      output
    end

    def stack_trace_section
      formatter = StackTraceFormatter.new(@exception.backtrace || [])
      output = ["STACK TRACE:"]
      output.concat(formatter.format)
      output
    end

    def request_info_section
      output = ["REQUEST INFO:"]
      output << "Method: #{@request.request_method}"
      output << "URL: #{@request.url}"

      unless @request.params.empty?
        output << "Params: #{@request.params.inspect}"
      end

      output
    end

    def variables_section
      return ["Variables inspection not available"] unless defined?(Binding)

      output = ["VARIABLES:"]
      output << "(Variable inspection would require binding_of_caller gem)"
      output
    end

    def abbreviate_path(path)
      return path unless @config.application_root

      path.sub(@config.application_root.to_s + '/', '')
    end
  end
end