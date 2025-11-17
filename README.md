# PlainErrors

A **Rails middleware** that provides concise, **plain text error output optimized for LLMs and coding agents**.

This lets your tool test your application and debug errors without filling up its context window.

For example, if you're using Playwright MCP with Claude Code or another
LLM-powered tool, PlainErrors will return simpler error messages.

## Token Comparison Summary

In my test with a real Rails application, PlainErrors achieves significant
token reductions over both
[BetterErrors](https://github.com/BetterErrors/better_errors)
and the standard Rails development error page
(as calculated by OpenAI's [`tiktoken`](https://github.com/openai/tiktoken) library):

| Metric | PlainErrors | Rails Default      | BetterErrors          |
| ------ | ----------- | ------------------ | --------------------- |
| Bytes  | 755         | 8,854              | 113,544               |
| Tokens | 217         | 2,975 (13.7x more) |  25,055 (115.5x more) |

(To be clear, I like BetterErrors and the Rails default error page -- they're great for manual human debugging.
They're just not optimized for LLMs or automation workflows.)


## Installation

_Cheat code: just point your AI agent to this README and ask it to install!_

Add to your Gemfile:

```ruby
group :development do
  gem 'plain_errors', github: 'panozzaj/plain_errors'
end
```

Then run `bundle install`.

## Setup

Add configuration and middleware in an initializer:

```ruby
# config/initializers/plain_errors.rb
if defined?(PlainErrors)
  PlainErrors.configure do |config|
    config.enabled = Rails.env.development?
    config.show_code_snippets = true
    config.code_lines_context = 2
    config.trigger_headers = ['X-Plain-Errors', 'X-LLM-Request']
  end

  # IMPORTANT: Must use insert_before ActionDispatch::ShowExceptions
  # Rails includes ShowExceptions by default which catches all exceptions.
  Rails.application.config.middleware.insert_before ActionDispatch::ShowExceptions, PlainErrors::Middleware
end
```

**Why `insert_before` is required:**

Rails always includes `ActionDispatch::ShowExceptions` in the middleware stack, which catches all exceptions and renders error pages. PlainErrors must be inserted **before** ShowExceptions to intercept exceptions when trigger conditions are met.

**Correct middleware order:**

```
PlainErrors::Middleware          ← Checks trigger conditions, intercepts if matched
ActionDispatch::ShowExceptions   ← Rails default error handler (fallback)
BetterErrors::Middleware         ← If installed
```

### Working with Other Error Handlers

PlainErrors should work when used before BetterErrors, Sentry, Honeybadger, and other error handlers:

- **When trigger conditions match** (e.g., `X-Plain-Errors: true` header): PlainErrors returns plain text
- **When trigger conditions don't match**: PlainErrors passes through to standard error handlers (BetterErrors, etc.)

This allows you to use PlainErrors for LLM / automation workflows while keeping BetterErrors for manual debugging.

**Important notes:**

- Middleware must be configured in an initializer (not in `config/environments/development.rb`)
- Use `config.verbose = true` for debugging if PlainErrors isn't triggering as expected

**Handling 404 errors:**

PlainErrors will catch and format 404 errors when placed before `ActionDispatch::ShowExceptions`. Rails routing errors (404s) don't raise exceptions through the middleware stack - they return 404 responses. PlainErrors detects these and returns succinct plain text like "404 Not Found: /path" when trigger conditions are met.

## Usage with Claude Code

To use PlainErrors with Claude Code's Playwright MCP server:

1. Add or modify Playwright MCP in `~/.claude/claude.json`:

```json
{
  ...
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "@playwright/mcp@latest",
        "--config=~/.claude/playwright-config.json"
      ],
      "env": {}
    }
  },
  ...
}
```

This can be a little tricky to hunt down if you have multiple projects servers
configured.  Perhaps it could go in a project-specific `.claude/claude.json`
file? (If you try this, please let me know how it goes!)

2. Create `~/.claude/playwright-config.json`:

```json
{
  "browser": {
    "contextOptions": {
      "extraHTTPHeaders": {
        "X-Plain-Errors": "true"
      }
    }
  }
}
```

This configures Playwright to send the `X-Plain-Errors` header with all requests, triggering plaintext error output.

## Triggering Plaintext Errors

PlainErrors decides whether to show plain text errors based on several conditions:

### Query Parameters (Highest Priority)

Override all other behavior with query strings:

```bash
# Force plaintext errors (overrides Accept headers)
curl http://localhost:3000/endpoint?force_plain_error=1

# Force standard Rails/BetterErrors (overrides all plain error triggers)
curl -H "X-Plain-Errors: 1" http://localhost:3000/endpoint?force_standard_error=1
```

### Headers

Send `X-Plain-Errors` with a truthy value (`1`, `true`, or `yes`) or any configured trigger header:

```bash
# All of these work:
curl -H "X-Plain-Errors: 1" http://localhost:3000/endpoint
curl -H "X-Plain-Errors: true" http://localhost:3000/endpoint
curl -H "X-Plain-Errors: yes" http://localhost:3000/endpoint
```

### Accept Header Behavior

PlainErrors also checks the `Accept` header:

- No Accept header → Plain text errors (for CLI tools, API clients)
- `Accept: text/plain` → Plain text errors
- `Accept: */*` (curl default) → Plain text errors
- `Accept: text/html` → Standard error handler (BetterErrors, etc.)

```bash
# These all trigger plain errors:
curl http://localhost:3000/endpoint                    # No Accept header
curl -H "Accept: text/plain" http://localhost:3000/endpoint
curl -H "Accept: */*" http://localhost:3000/endpoint

# This uses standard error handler:
curl -H "Accept: text/html" http://localhost:3000/endpoint
```

### Priority Order

1. `force_standard_error=1` query param (passes through to standard handler)
2. `force_plain_error=1` query param (shows plain errors)
3. Configured trigger headers (e.g., `X-Plain-Errors: 1`)
4. Accept header check (see above)

## Example Output

```
ERROR
StandardError: This is a test error to verify plain_errors is working!

TRACE
0: app/controllers/debug_controller.rb:5:in `test_error'
1: actionpack (7.2.2.2) lib/action_controller/metal/basic_implicit_render.rb:8:in `send_action'
2: actionpack (7.2.2.2) lib/abstract_controller/base.rb:226:in `process_action'
3: actionpack (7.2.2.2) lib/action_controller/metal/rendering.rb:193:in `process_action'
4: actionpack (7.2.2.2) lib/abstract_controller/callbacks.rb:261:in `block in process_action'
(99 more lines omitted)

app/controllers/debug_controller.rb:5
3: class DebugController < ActionController::Base
4:   def test_error
5:     raise StandardError, "This is a test error to verify plain_errors is working!"
6:   end
7:
8:   def middleware
```

## Non-Rails Usage

I haven't tested PlainErrors outside of Rails, but it should work in any Rack-based application.
If you run into issues with other frameworks, please open an issue.


## Configuration Options

| Option                  | Default                               | Description                               |
| ------                  | -------                               | -----------                               |
| `enabled`               | `Rails.env.development?`              | Enable/disable the middleware             |
| `show_code_snippets`    | `true`                                | Include source code section (set to `false` to disable entirely) |
| `code_lines_context`    | `2`                                   | Lines of context: `0` = error line only, `1+` = lines before/after |
| `show_request_info`     | `false`                               | Include HTTP request details              |
| `max_stack_trace_lines` | `5`                                   | Max stack trace lines (nil for unlimited) |
| `application_root`      | `Rails.root`                          | Root path for abbreviating paths          |
| `trigger_headers`       | `['X-Plain-Errors', 'X-LLM-Request']` | Headers that trigger plaintext output     |
| `verbose`               | `false`                               | Enable verbose debug logging to stderr    |

### Code Snippet Behavior

- `show_code_snippets: false` → No code section displayed
- `show_code_snippets: true` + `code_lines_context: 0` → Shows only the error line
- `show_code_snippets: true` + `code_lines_context: 2` → Shows 2 lines before and after the error (default)

## Debugging

If PlainErrors isn't working as expected, enable verbose mode to see detailed logging:

```ruby
# config/initializers/plain_errors.rb
PlainErrors.configure do |config|
  # ...
  config.verbose = true
end
```

## Security

⚠️ **Only enable in development environments.** PlainErrors exposes application internals and source code.

## License

Available under the [MIT License](https://opensource.org/licenses/MIT).
