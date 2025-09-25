module PlainErrors
  class Configuration
    attr_accessor :enabled,
                  :show_code_snippets,
                  :code_lines_context,
                  :show_request_info,
                  :show_variables,
                  :max_variable_size,
                  :application_root,
                  :trigger_headers

    def initialize
      @enabled = Rails.env.development? if defined?(Rails)
      @enabled = true if @enabled.nil?
      @show_code_snippets = true
      @code_lines_context = 3
      @show_request_info = false
      @show_variables = false
      @max_variable_size = 1000
      @application_root = Rails.root if defined?(Rails)
      @trigger_headers = ['X-Plain-Errors', 'X-LLM-Request']
    end
  end
end