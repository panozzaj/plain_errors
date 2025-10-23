module PlainErrors
  class Configuration
    attr_accessor :enabled,
                  :show_code_snippets,
                  :code_lines_context,
                  :show_request_info,
                  :application_root,
                  :trigger_headers,
                  :verbose,
                  :max_stack_trace_lines

    def initialize
      @enabled = Rails.env.development? if defined?(Rails)
      @enabled = true if @enabled.nil?
      @show_code_snippets = true
      @code_lines_context = 2
      @show_request_info = false
      @application_root = Rails.root if defined?(Rails)
      @trigger_headers = ['X-Plain-Errors', 'X-LLM-Request']
      @verbose = false
      @max_stack_trace_lines = 5  # Limit to 5 lines by default for conciseness
    end
  end
end