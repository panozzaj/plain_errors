module PlainErrors
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue Exception => exception
      return @app.call(env) unless PlainErrors.configuration.enabled
      return @app.call(env) unless text_request?(env)

      request = Rack::Request.new(env)
      formatter = Formatter.new(exception, request)

      [
        500,
        { 'Content-Type' => 'text/plain; charset=utf-8' },
        [formatter.format]
      ]
    end

    private

    def text_request?(env)
      PlainErrors.configuration.trigger_headers.each do |header|
        env_key = "HTTP_#{header.upcase.gsub('-', '_')}"
        return true if env[env_key] == '1'
      end

      return true if env['HTTP_ACCEPT'].nil?

      accept_header = env['HTTP_ACCEPT'].to_s.downcase
      return true if accept_header.include?('text/plain')
      return true if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'

      !accept_header.include?('text/html')
    end
  end
end