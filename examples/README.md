# PlainErrors Examples

Example files to test PlainErrors in your Rails app.

## Setup

1. Copy `debug_controller.rb` to `app/controllers/`
2. Add routes from `routes.rb` to `config/routes.rb`

## Usage

```bash
# Test with PlainErrors
curl -H "X-Plain-Errors: 1" http://localhost:3000/debug/test_error

# Test without PlainErrors (shows default Rails/BetterErrors output)
curl http://localhost:3000/debug/test_error
```

## Sample Output

```
ERROR
StandardError: This is a test error to verify plain_errors is working!

TRACE
0: app/controllers/debug_controller.rb:5:in `test_error'
1: actionpack (7.2.2.2) lib/action_controller/metal/basic_implicit_render.rb:8:in `send_action'
2: actionpack (7.2.2.2) lib/abstract_controller/base.rb:226:in `process_action'
(99 more lines omitted)

app/controllers/debug_controller.rb:5
3: class DebugController < ActionController::Base
4:   def test_error
5:     raise StandardError, "This is a test error to verify plain_errors is working!"
6:   end
```

## Test Endpoints

- `/debug/test_error` - Simple StandardError
- `/debug/test_nil_error` - NoMethodError on nil
- `/debug/middleware` - View middleware stack
