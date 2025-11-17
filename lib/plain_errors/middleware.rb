# frozen_string_literal: true

module PlainErrors
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      # Check if an exception occurred (stored in env by Rails or error tracking middleware)
      # This handles cases where ShowExceptions or other middleware caught it
      # Handle both 4xx (client errors like 404) and 5xx (server errors)
      if status >= 400
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

        # For 404s without exception (routing errors), handle if plain errors should be triggered
        if status == 404 && should_handle_request?(env)
          log 'Handling 404 without exception' if PlainErrors.configuration.verbose
          return handle_404_without_exception(env, status, headers, body)
        end
      end

      [status, headers, body]
    rescue Exception => e
      # Caught an exception that wasn't handled by middleware below
      log "Caught exception in rescue: #{e.class}" if PlainErrors.configuration.verbose
      handle_exception(e, env)
    end

    private

    def handle_exception(exception, env, status = nil, headers = nil, body = nil)
      # Re-raise if not enabled (only if we can re-raise)
      unless PlainErrors.configuration.enabled
        log 'Disabled, passing through' if PlainErrors.configuration.verbose
        return status ? [status, headers, body] : raise(exception)
      end

      request = Rack::Request.new(env)
      log "query_string = #{request.query_string.inspect}" if PlainErrors.configuration.verbose

      # Check for query string overrides first
      if request.query_string&.include?('force_standard_error=1')
        log 'Returning original response due to force_standard_error' if PlainErrors.configuration.verbose
        return status ? [status, headers, body] : raise(exception)
      end

      # Check if we should handle this request
      should_handle = request.query_string&.include?('force_plain_error=1') || text_request?(env)
      log "should_handle = #{should_handle}" if PlainErrors.configuration.verbose

      unless should_handle
        log 'Not handling request, passing through' if PlainErrors.configuration.verbose
        return status ? [status, headers, body] : raise(exception)
      end

      # Generate plain error response
      log 'Generating plain error response' if PlainErrors.configuration.verbose
      formatter = Formatter.new(exception, request)

      [
        500,
        { 'Content-Type' => 'text/plain; charset=utf-8' },
        [formatter.format]
      ]
    end

    def text_request?(env)
      # Check trigger headers first - these override Accept header
      PlainErrors.configuration.trigger_headers.each do |header|
        env_key = "HTTP_#{header.upcase.tr('-', '_')}"
        log "Checking #{env_key} = #{env[env_key].inspect}" if PlainErrors.configuration.verbose
        # Accept "1", "true", "yes", or any truthy value
        next unless /^(1|true|yes)$/.match?(env[env_key].to_s.downcase)

        if PlainErrors.configuration.verbose
          log "Trigger header #{header} matched, returning true (overrides Accept header)"
        end
        return true
      end

      # No trigger headers matched, check Accept header
      if env['HTTP_ACCEPT'].nil?
        log 'No Accept header, treating as text request' if PlainErrors.configuration.verbose
        return true
      end

      accept_header = env['HTTP_ACCEPT'].to_s.downcase
      log "Checking Accept header: #{accept_header}" if PlainErrors.configuration.verbose

      if accept_header.include?('text/plain')
        log 'Accept header includes text/plain, returning true' if PlainErrors.configuration.verbose
        return true
      end

      if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
        log 'XMLHttpRequest detected, returning true' if PlainErrors.configuration.verbose
        return true
      end

      result = !accept_header.include?('text/html')
      if PlainErrors.configuration.verbose
        log "text_request? returning #{result} (no trigger headers, accept: #{accept_header})"
      end
      result
    end

    def should_handle_request?(env)
      return false unless PlainErrors.configuration.enabled

      request = Rack::Request.new(env)
      return true if request.query_string&.include?('force_plain_error=1')

      text_request?(env)
    end

    def handle_404_without_exception(env, status, _headers, _body)
      request = Rack::Request.new(env)

      # Extract the path from the body if it's a "Not Found" response
      path = request.path

      error_message = "404 Not Found: #{path}"

      [
        status,
        { 'Content-Type' => 'text/plain; charset=utf-8' },
        [error_message]
      ]
    end

    def log(message)
      warn "PlainErrors: #{message}"
    end
  end
end
