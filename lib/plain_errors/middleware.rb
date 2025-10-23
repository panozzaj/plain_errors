module PlainErrors
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      # Check if an exception occurred (stored in env by Rails or error tracking middleware)
      # This handles cases where ShowExceptions or other middleware caught it
      if status >= 500
        if PlainErrors.configuration.verbose
          exception_keys = env.keys.select { |k| k.to_s =~ /exception|error|rescued/i }
          log "status=#{status}, exception keys in env: #{exception_keys.inspect}"
          exception_keys.each { |k| log "  #{k} = #{env[k].class}" }
        end

        exception = env['action_dispatch.exception'] || env['sentry.rescued_exception']
        if exception
          log "Handling exception from env: #{exception.class}" if PlainErrors.configuration.verbose
          return handle_exception(exception, env, status, headers, body)
        end
      end

      [status, headers, body]
    rescue Exception => exception
      # Caught an exception that wasn't handled by middleware below
      log "Caught exception in rescue: #{exception.class}" if PlainErrors.configuration.verbose
      return handle_exception(exception, env)
    end

    private

    def handle_exception(exception, env, status = nil, headers = nil, body = nil)
      # Re-raise if not enabled (only if we can re-raise)
      if !PlainErrors.configuration.enabled
        log "Disabled, passing through" if PlainErrors.configuration.verbose
        return status ? [status, headers, body] : raise(exception)
      end

      request = Rack::Request.new(env)
      log "query_string = #{request.query_string.inspect}" if PlainErrors.configuration.verbose

      # Check for query string overrides first
      if request.query_string&.include?('force_standard_error=1')
        log "Returning original response due to force_standard_error" if PlainErrors.configuration.verbose
        return status ? [status, headers, body] : raise(exception)
      end

      # Check if we should handle this request
      should_handle = request.query_string&.include?('force_plain_error=1') || text_request?(env)
      log "should_handle = #{should_handle}" if PlainErrors.configuration.verbose

      unless should_handle
        log "Not handling request, passing through" if PlainErrors.configuration.verbose
        return status ? [status, headers, body] : raise(exception)
      end

      # Generate plain error response
      log "Generating plain error response" if PlainErrors.configuration.verbose
      formatter = Formatter.new(exception, request)

      [
        500,
        { 'Content-Type' => 'text/plain; charset=utf-8' },
        [formatter.format]
      ]
    end

    def text_request?(env)
      PlainErrors.configuration.trigger_headers.each do |header|
        env_key = "HTTP_#{header.upcase.gsub('-', '_')}"
        log "Checking #{env_key} = #{env[env_key].inspect}" if PlainErrors.configuration.verbose
        # Accept "1", "true", "yes", or any truthy value
        if env[env_key].to_s.downcase =~ /^(1|true|yes)$/
          return true
        end
      end

      if env['HTTP_ACCEPT'].nil?
        log "No Accept header, treating as text request" if PlainErrors.configuration.verbose
        return true
      end

      accept_header = env['HTTP_ACCEPT'].to_s.downcase
      return true if accept_header.include?('text/plain')
      return true if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'

      result = !accept_header.include?('text/html')
      log "text_request? returning #{result} (accept: #{accept_header})" if PlainErrors.configuration.verbose
      result
    end

    def log(message)
      $stderr.puts "PlainErrors: #{message}"
    end
  end
end