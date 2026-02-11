# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PlainErrors::Middleware do
  include Rack::Test::Methods

  let(:app) do
    lambda do |env|
      case env['PATH_INFO']
      when '/error'
        raise StandardError, 'Test error message'
      when '/success'
        [200, {}, ['Success']]
      else
        [404, {}, ['Not Found']]
      end
    end
  end

  let(:middleware) { described_class.new(app) }

  before do
    PlainErrors.configure do |config|
      config.enabled = true
      config.show_code_snippets = false
      config.show_request_info = false
    end
  end

  describe '#call' do
    context 'when no exception occurs' do
      it 'passes through to the app' do
        env = { 'PATH_INFO' => '/success' }
        response = middleware.call(env)
        expect(response).to eq([200, {}, ['Success']])
      end
    end

    context 'when an exception occurs' do
      context 'when middleware is disabled' do
        before { PlainErrors.configuration.enabled = false }

        it 'lets the exception propagate' do
          env = { 'PATH_INFO' => '/error' }
          expect { middleware.call(env) }.to raise_error(StandardError, 'Test error message')
        end
      end

      context 'when middleware is enabled' do
        context 'with text request' do
          it 'returns plaintext error response' do
            env = {
              'PATH_INFO' => '/error',
              'HTTP_ACCEPT' => 'text/plain'
            }

            response = middleware.call(env)
            status, headers, body = response

            expect(status).to eq 500
            expect(headers['Content-Type']).to eq 'text/plain; charset=utf-8'
            expect(body.first).to include('ERROR')
            expect(body.first).to include('StandardError: Test error message')
          end

          it 'handles XMLHttpRequest' do
            env = {
              'PATH_INFO' => '/error',
              'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'
            }

            response = middleware.call(env)
            status, headers, body = response

            expect(status).to eq 500
            expect(headers['Content-Type']).to eq 'text/plain; charset=utf-8'
            expect(body.first).to include('ERROR')
            expect(body.first).to include('StandardError: Test error message')
          end

          it 'handles default trigger headers' do
            env = {
              'PATH_INFO' => '/error',
              'HTTP_X_PLAIN_ERRORS' => '1'
            }

            response = middleware.call(env)
            expect(response[0]).to eq 500

            env = {
              'PATH_INFO' => '/error',
              'HTTP_X_LLM_REQUEST' => '1'
            }

            response = middleware.call(env)
            expect(response[0]).to eq 500
          end
        end

        context 'with HTML request' do
          it 'lets the exception propagate' do
            env = {
              'PATH_INFO' => '/error',
              'HTTP_ACCEPT' => 'text/html'
            }

            expect { middleware.call(env) }.to raise_error(StandardError, 'Test error message')
          end
        end

        context 'with no Accept header' do
          it 'lets the exception propagate (conservative default)' do
            env = { 'PATH_INFO' => '/error' }

            expect { middleware.call(env) }.to raise_error(StandardError, 'Test error message')
          end
        end

        context 'with wildcard Accept header (*/*)' do
          it 'lets the exception propagate (browser-like request)' do
            env = {
              'PATH_INFO' => '/error',
              'HTTP_ACCEPT' => '*/*'
            }

            expect { middleware.call(env) }.to raise_error(StandardError, 'Test error message')
          end
        end

        context 'with query string overrides' do
          it 'forces plain error when force_plain_error=1' do
            env = {
              'PATH_INFO' => '/error',
              'HTTP_ACCEPT' => 'text/html',
              'QUERY_STRING' => 'force_plain_error=1'
            }

            response = middleware.call(env)
            status, headers, body = response

            expect(status).to eq 500
            expect(headers['Content-Type']).to eq 'text/plain; charset=utf-8'
            expect(body.first).to include('ERROR')
            expect(body.first).to include('StandardError: Test error message')
          end

          it 'forces standard error when force_standard_error=1' do
            env = {
              'PATH_INFO' => '/error',
              'HTTP_ACCEPT' => 'text/plain',
              'QUERY_STRING' => 'force_standard_error=1'
            }

            expect { middleware.call(env) }.to raise_error(StandardError, 'Test error message')
          end

          it 'works with other query parameters' do
            env = {
              'PATH_INFO' => '/error',
              'HTTP_ACCEPT' => 'text/html',
              'QUERY_STRING' => 'other=value&force_plain_error=1&another=param'
            }

            response = middleware.call(env)
            expect(response[0]).to eq 500
          end

          it 'prioritizes force_standard_error over force_plain_error' do
            env = {
              'PATH_INFO' => '/error',
              'HTTP_ACCEPT' => 'text/plain',
              'QUERY_STRING' => 'force_plain_error=1&force_standard_error=1'
            }

            expect { middleware.call(env) }.to raise_error(StandardError, 'Test error message')
          end
        end
      end
    end
  end

  describe '#text_request?' do
    let(:middleware_instance) { described_class.new(app) }

    it 'returns true for text/plain accept header' do
      env = { 'HTTP_ACCEPT' => 'text/plain' }
      expect(middleware_instance.send(:text_request?, env)).to be true
    end

    it 'returns true for XMLHttpRequest' do
      env = { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
      expect(middleware_instance.send(:text_request?, env)).to be true
    end

    it 'returns false for text/html accept header' do
      env = { 'HTTP_ACCEPT' => 'text/html' }
      expect(middleware_instance.send(:text_request?, env)).to be false
    end

    it 'returns false when no Accept header is present (conservative default)' do
      env = {}
      expect(middleware_instance.send(:text_request?, env)).to be false
    end

    it 'returns false for wildcard Accept header (*/*) (browser-like request)' do
      env = { 'HTTP_ACCEPT' => '*/*' }
      expect(middleware_instance.send(:text_request?, env)).to be false
    end

    it 'returns true for application/json Accept (non-browser, non-wildcard)' do
      env = { 'HTTP_ACCEPT' => 'application/json' }
      expect(middleware_instance.send(:text_request?, env)).to be true
    end

    it 'returns true for mixed accept header without html' do
      env = { 'HTTP_ACCEPT' => 'application/json, text/plain' }
      expect(middleware_instance.send(:text_request?, env)).to be true
    end

    it 'returns true when text/plain and */* are both present (text/plain wins)' do
      env = { 'HTTP_ACCEPT' => 'text/plain, */*' }
      expect(middleware_instance.send(:text_request?, env)).to be true
    end

    it 'returns true for XMLHttpRequest even with text/html Accept' do
      env = { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest', 'HTTP_ACCEPT' => 'text/html' }
      expect(middleware_instance.send(:text_request?, env)).to be true
    end

    it 'returns false for typical browser Accept header' do
      env = { 'HTTP_ACCEPT' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' }
      expect(middleware_instance.send(:text_request?, env)).to be false
    end

    it 'returns true for configured trigger headers' do
      env = { 'HTTP_X_PLAIN_ERRORS' => '1' }
      expect(middleware_instance.send(:text_request?, env)).to be true

      env = { 'HTTP_X_LLM_REQUEST' => '1' }
      expect(middleware_instance.send(:text_request?, env)).to be true
    end

    it 'accepts truthy header values: 1, true, yes' do
      # Test "1"
      env = { 'HTTP_X_PLAIN_ERRORS' => '1' }
      expect(middleware_instance.send(:text_request?, env)).to be true

      # Test "true"
      env = { 'HTTP_X_PLAIN_ERRORS' => 'true' }
      expect(middleware_instance.send(:text_request?, env)).to be true

      # Test "yes"
      env = { 'HTTP_X_PLAIN_ERRORS' => 'yes' }
      expect(middleware_instance.send(:text_request?, env)).to be true

      # Test case insensitivity
      env = { 'HTTP_X_PLAIN_ERRORS' => 'TRUE' }
      expect(middleware_instance.send(:text_request?, env)).to be true

      env = { 'HTTP_X_PLAIN_ERRORS' => 'Yes' }
      expect(middleware_instance.send(:text_request?, env)).to be true

      # Test invalid values (with HTML Accept header to ensure they don't fall through to default)
      env = { 'HTTP_X_PLAIN_ERRORS' => 'false', 'HTTP_ACCEPT' => 'text/html' }
      expect(middleware_instance.send(:text_request?, env)).to be false

      env = { 'HTTP_X_PLAIN_ERRORS' => '0', 'HTTP_ACCEPT' => 'text/html' }
      expect(middleware_instance.send(:text_request?, env)).to be false

      env = { 'HTTP_X_PLAIN_ERRORS' => 'random', 'HTTP_ACCEPT' => 'text/html' }
      expect(middleware_instance.send(:text_request?, env)).to be false
    end

    it 'handles custom trigger headers' do
      original_headers = PlainErrors.configuration.trigger_headers

      PlainErrors.configure do |config|
        config.trigger_headers = ['X-Custom-Header']
      end

      env = { 'HTTP_X_CUSTOM_HEADER' => '1' }
      expect(middleware_instance.send(:text_request?, env)).to be true

      env = { 'HTTP_X_PLAIN_ERRORS' => '1', 'HTTP_ACCEPT' => 'text/html' }
      expect(middleware_instance.send(:text_request?, env)).to be false

      # Reset configuration
      PlainErrors.configure do |config|
        config.trigger_headers = original_headers
      end
    end
  end
end
