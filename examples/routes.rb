# Example routes for the debug controller
# Add these to your config/routes.rb file

Rails.application.routes.draw do
  # Debug routes - only available in development
  if Rails.env.development?
    get "debug/test_error", to: "debug#test_error"
    get "debug/test_nil_error", to: "debug#test_nil_error"
    get "debug/middleware", to: "debug#middleware"
  end

  # Your other routes...
end
