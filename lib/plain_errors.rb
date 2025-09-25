require_relative 'plain_errors/configuration'
require_relative 'plain_errors/middleware'
require_relative 'plain_errors/formatter'
require_relative 'plain_errors/code_extractor'
require_relative 'plain_errors/stack_trace_formatter'

module PlainErrors
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end