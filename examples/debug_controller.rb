# frozen_string_literal: true

# Example debug controller for testing plain_errors
#
# To use in your Rails app:
# 1. Copy this file to app/controllers/debug_controller.rb
# 2. Add routes in config/routes.rb:
#
#    if Rails.env.development?
#      get "debug/test_error", to: "debug#test_error"
#      get "debug/test_nil_error", to: "debug#test_nil_error"
#      get "debug/middleware", to: "debug#middleware"
#    end
#
# 3. Visit http://localhost:3000/debug/test_error with X-Plain-Errors header

class DebugController < ActionController::Base
  # Simple error for testing
  def test_error
    raise StandardError, "This is a test error to verify plain_errors is working!"
  end

  # Realistic NoMethodError - calling method on nil
  def test_nil_error
    user = nil
    user.email.upcase  # NoMethodError: undefined method `email' for nil
  end

  # Show the middleware stack (useful for verifying plain_errors is loaded)
  def middleware
    middlewares = []
    Rails.application.middleware.each do |m|
      middlewares << m.name
    end
    render plain: middlewares.join("\n")
  end
end
