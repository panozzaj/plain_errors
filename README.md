# PlainErrors

A Rails middleware inspired by [better_errors](https://github.com/BetterErrors/better_errors) that provides concise, token-efficient plaintext error output. Optimized for LLMs and coding agents that need to understand Rails errors without consuming excessive tokens.

## Features

- **Minimal plaintext output** - Concise error formatting optimized for LLMs
- **Code snippet extraction** - Shows relevant source code around the error
- **Stack trace formatting** - Clean, readable stack traces
- **Configurable output** - Control what information is included
- **Special header support** - Easy integration with Playwright MCP and other tools

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'plain_errors', group: :development
```

And then execute:

```bash
$ bundle install
```

## Usage

### Basic Setup

Add the middleware to your Rails application:

```ruby
# config/environments/development.rb
config.middleware.use PlainErrors::Middleware
```

### Configuration

Configure the middleware in an initializer:

```ruby
# config/initializers/plain_errors.rb
if defined?(PlainErrors)
  PlainErrors.configure do |config|
    config.enabled = Rails.env.development?
    config.show_code_snippets = true
    config.code_lines_context = 3
    config.show_request_info = false
    config.show_variables = false
    config.application_root = Rails.root
  end
end
```

### Integration with Playwright MCP and LLM Tools

The primary way to use this middleware is by sending a special header with your requests. This is especially useful for Playwright MCP requests from coding agents:

#### Option 1: X-Plain-Errors Header (Recommended)

Send the `X-Plain-Errors: 1` header with your requests:

```javascript
// Playwright MCP example
await page.setExtraHTTPHeaders({
  'X-Plain-Errors': '1'
});

await page.goto('http://localhost:3000/some-endpoint');
```

```bash
# cURL example
curl -H "X-Plain-Errors: 1" http://localhost:3000/some-endpoint
```

#### Option 2: X-LLM-Request Header

Alternatively, use the `X-LLM-Request: 1` header:

```javascript
await page.setExtraHTTPHeaders({
  'X-LLM-Request': '1'
});
```

#### Option 3: Content-Type Negotiation

The middleware also responds to:
- `Accept: text/plain` header
- XMLHttpRequest requests
- Requests without an Accept header

#### Option 4: Query String Parameters

You can override the default behavior using query string parameters:

```bash
# Force plain error output (ignores headers/content negotiation)
curl http://localhost:3000/some-endpoint?force_plain_error=1

# Force standard Rails error handling (bypasses plain errors)
curl http://localhost:3000/some-endpoint?force_standard_error=1
```

**Query Parameter Priority:**
- `force_standard_error=1` takes priority over all other settings
- `force_plain_error=1` overrides header-based detection
- Both work with other query parameters: `?debug=true&force_plain_error=1`

### Sample Output

When an error occurs, you'll get plaintext output like:

```
ERROR: NoMethodError: undefined method `non_existent_method' for #<User:0x00007f8b1c0d3e40>

CODE SNIPPET:
File: app/controllers/users_controller.rb:15

    13:   def show
    14:     @user = User.find(params[:id])
>>> 15:     @user.non_existent_method
    16:     render json: @user
    17:   end

STACK TRACE:
  0: ./app/controllers/users_controller.rb:15:in `show'
  1: ./app/controllers/application_controller.rb:8:in `process_action'
  2: /gems/actionpack-7.0.0/lib/action_controller/metal.rb:190:in `dispatch'
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `Rails.env.development?` | Enable/disable the middleware |
| `show_code_snippets` | `true` | Include source code around error lines |
| `code_lines_context` | `3` | Number of lines before/after error to show |
| `show_request_info` | `false` | Include HTTP request details |
| `show_variables` | `false` | Include variable inspection (requires binding_of_caller) |
| `max_variable_size` | `1000` | Maximum size for variable inspection |
| `application_root` | `Rails.root` | Root path for abbreviating file paths |
| `trigger_headers` | `['X-Plain-Errors', 'X-LLM-Request']` | HTTP headers that trigger plaintext error output |

## Rails Integration

### Automatic Setup (Recommended)

Create a Rails initializer to automatically add the middleware in development:

```ruby
# config/initializers/plain_errors.rb
if Rails.env.development?
  Rails.application.config.middleware.use PlainErrors::Middleware

  PlainErrors.configure do |config|
    config.show_code_snippets = true
    config.code_lines_context = 5
    config.show_request_info = ENV['PLAIN_ERRORS_VERBOSE'] == '1'
    config.trigger_headers = ['X-Plain-Errors', 'X-My-Custom-Agent']
  end
end
```

#### Middleware Stack Positioning

**If using with better_errors or similar gems**, place PlainErrors **before** them in the middleware stack to ensure it takes precedence for requests with trigger headers:

```ruby
# config/application.rb
# PlainErrors should come BEFORE better_errors in the stack
config.middleware.insert_before BetterErrors::Middleware, PlainErrors::Middleware

# Or insert after ShowExceptions but before other error handlers
config.middleware.insert_after ActionDispatch::ShowExceptions, PlainErrors::Middleware
```

**Why order matters**: Middleware executes in order, so PlainErrors should come first to intercept requests with the special headers before other error handling middleware processes them.

#### Development with Multiple Error Tools

Common setup when using both PlainErrors (for LLM/agents) and better_errors (for human developers):

```ruby
# config/environments/development.rb
if defined?(BetterErrors)
  # PlainErrors goes first to catch trigger headers
  config.middleware.insert_before BetterErrors::Middleware, PlainErrors::Middleware
else
  config.middleware.use PlainErrors::Middleware
end

PlainErrors.configure do |config|
  config.enabled = true
  config.show_code_snippets = true
  config.trigger_headers = ['X-Plain-Errors', 'X-LLM-Request', 'X-Playwright-MCP']
end
```

## Security

⚠️ **Important**: This middleware should only be enabled in development environments. It can expose sensitive application internals and source code.

The middleware is disabled by default in production, but always verify your configuration:

```ruby
# Explicitly disable in production
PlainErrors.configure do |config|
  config.enabled = false if Rails.env.production?
end
```

## Why PlainErrors?

- **LLM-Optimized**: Minimal token usage while providing essential debugging info
- **Coding Agent Friendly**: Easy integration with automated tools via headers
- **Developer Friendly**: Clean, readable output that's easy to scan
- **Configurable**: Show only what you need for your specific use case

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the [MIT License](https://opensource.org/licenses/MIT).
