require 'spec_helper'
require 'tempfile'

RSpec.describe PlainErrors::Formatter do
  let(:exception) do
    error = StandardError.new('Test error message')
    error.set_backtrace([
      '/app/controllers/test_controller.rb:15:in `show\'',
      '/app/models/user.rb:42:in `find_user\'',
      '/usr/local/ruby/lib/rack.rb:123:in `call\''
    ])
    error
  end

  let(:request) do
    double('request',
           request_method: 'GET',
           url: 'http://example.com/users/1',
           params: { 'id' => '1', 'format' => 'json' })
  end

  before do
    PlainErrors.configure do |config|
      config.application_root = '/app'
      config.show_code_snippets = true
      config.code_lines_context = 2
      config.show_request_info = false
    end
  end

  describe '#format' do
    context 'basic error formatting' do
      it 'includes error class and message' do
        formatter = described_class.new(exception)
        result = formatter.format

        expect(result).to include('ERROR')
        expect(result).to include('StandardError: Test error message')
      end

      it 'includes stack trace section' do
        formatter = described_class.new(exception)
        result = formatter.format

        expect(result).to include('TRACE')
        expect(result).to include('0: ')
      end
    end

    context 'with code snippets enabled' do
      let(:sample_code) do
        <<~RUBY
          class TestController
            def show
              user = find_user
              raise 'Test error'
              render json: user
            end
          end
        RUBY
      end

      let(:temp_file) do
        file = Tempfile.new(['test_controller', '.rb'])
        file.write(sample_code)
        file.close
        file
      end

      after { temp_file.unlink }

      before do
        exception.set_backtrace(["#{temp_file.path}:4:in `show'"])
      end

      it 'includes code snippet section' do
        formatter = described_class.new(exception)
        result = formatter.format

        expect(result).to include("#{temp_file.path}:4")
        expect(result).to include('4:     raise \'Test error\'')
      end

      it 'shows file path with line number' do
        formatter = described_class.new(exception)
        result = formatter.format

        expect(result).to include("#{temp_file.path}:4")
        expect(result).not_to include("File:")
      end
    end

    context 'with code snippets disabled' do
      let(:sample_code) { "raise 'Test error'\n" }
      let(:temp_file) do
        file = Tempfile.new(['test_disabled', '.rb'])
        file.write(sample_code)
        file.close
        file
      end

      after { temp_file.unlink }

      before do
        exception.set_backtrace(["#{temp_file.path}:1:in `test'"])
        PlainErrors.configuration.show_code_snippets = false
      end

      it 'does not include code snippet section' do
        formatter = described_class.new(exception)
        result = formatter.format

        # Should have ERROR and TRACE
        expect(result).to include('ERROR')
        expect(result).to include('TRACE')
        # Should NOT have code content lines
        expect(result).not_to match(/1: raise 'Test error'/)
        # The file path will still appear in TRACE but not as a code section
        lines = result.split("\n")
        # Count how many times the temp file path appears - should only be in TRACE
        path_count = lines.count { |line| line.include?(temp_file.path) }
        expect(path_count).to eq(1) # Only in the trace line
      end
    end

    context 'with code_lines_context set to 0' do
      let(:sample_code) do
        <<~RUBY
          # Line before
          raise 'Test error'
          # Line after
        RUBY
      end

      let(:temp_file) do
        file = Tempfile.new(['test_zero_context', '.rb'])
        file.write(sample_code)
        file.close
        file
      end

      after { temp_file.unlink }

      before do
        exception.set_backtrace(["#{temp_file.path}:2:in `test'"])
        PlainErrors.configuration.code_lines_context = 0
      end

      it 'shows only the error line without context' do
        formatter = described_class.new(exception)
        result = formatter.format

        expect(result).to include('ERROR')
        expect(result).to include('TRACE')
        # Should show only the error line
        expect(result).to include("2: raise 'Test error'")
        # Should NOT show context lines
        expect(result).not_to include('# Line before')
        expect(result).not_to include('# Line after')
      end
    end

    context 'with custom code_lines_context' do
      let(:sample_code) do
        <<~RUBY
          # Line 1
          # Line 2
          # Line 3
          # Line 4
          raise 'Error on line 5'
          # Line 6
          # Line 7
          # Line 8
          # Line 9
        RUBY
      end

      let(:temp_file) do
        file = Tempfile.new(['test_context', '.rb'])
        file.write(sample_code)
        file.close
        file
      end

      after { temp_file.unlink }

      before do
        exception.set_backtrace(["#{temp_file.path}:5:in `test'"])
      end

      it 'uses code_lines_context configuration' do
        # Default is 2 lines of context
        PlainErrors.configuration.code_lines_context = 2
        formatter = described_class.new(exception)
        result = formatter.format

        # Should have lines 3-7 (2 before, error line, 2 after)
        expect(result).to include('3: # Line 3')
        expect(result).to include('5: raise \'Error on line 5\'')
        expect(result).to include('7: # Line 7')
        expect(result).not_to include('2: # Line 2')
        expect(result).not_to include('8: # Line 8')
      end

      it 'respects custom code_lines_context value' do
        PlainErrors.configuration.code_lines_context = 1
        formatter = described_class.new(exception)
        result = formatter.format

        # Should have lines 4-6 (1 before, error line, 1 after)
        expect(result).to include('4: # Line 4')
        expect(result).to include('5: raise \'Error on line 5\'')
        expect(result).to include('6: # Line 6')
        expect(result).not_to include('3: # Line 3')
        expect(result).not_to include('7: # Line 7')
      end
    end

    context 'with request info enabled' do
      before { PlainErrors.configuration.show_request_info = true }

      it 'includes request information' do
        formatter = described_class.new(exception, request)
        result = formatter.format

        expect(result).to include('REQUEST INFO:')
        expect(result).to include('Method: GET')
        expect(result).to include('URL: http://example.com/users/1')
        expect(result).to include('Params: {"id"=>"1", "format"=>"json"}')
      end
    end

    context 'without request' do
      it 'does not include request info even when enabled' do
        PlainErrors.configuration.show_request_info = true
        formatter = described_class.new(exception)
        result = formatter.format

        expect(result).not_to include('REQUEST INFO:')
      end
    end
  end

  describe '#source_location' do
    let(:formatter) { described_class.new(exception) }

    context 'with valid backtrace' do
      it 'extracts file and line from first backtrace entry' do
        location = formatter.send(:source_location)

        expect(location[:file]).to eq('/app/controllers/test_controller.rb')
        expect(location[:line]).to eq(15)
      end
    end

    context 'with no backtrace' do
      let(:exception_without_backtrace) do
        StandardError.new('Test error')
      end

      it 'returns nil' do
        formatter = described_class.new(exception_without_backtrace)
        location = formatter.send(:source_location)

        expect(location).to be_nil
      end
    end

    context 'with malformed backtrace' do
      before do
        exception.set_backtrace(['invalid backtrace format'])
      end

      it 'returns nil' do
        location = formatter.send(:source_location)
        expect(location).to be_nil
      end
    end
  end

  describe '#abbreviate_path' do
    let(:formatter) { described_class.new(exception) }

    it 'abbreviates paths within application root' do
      path = '/app/controllers/users_controller.rb'
      result = formatter.send(:abbreviate_path, path)

      expect(result).to eq('controllers/users_controller.rb')
    end

    it 'leaves paths outside application root unchanged' do
      path = '/usr/local/ruby/lib/file.rb'
      result = formatter.send(:abbreviate_path, path)

      expect(result).to eq(path)
    end

    context 'without application root' do
      before { PlainErrors.configuration.application_root = nil }

      it 'returns original path' do
        path = '/app/controllers/users_controller.rb'
        result = formatter.send(:abbreviate_path, path)

        expect(result).to eq(path)
      end
    end
  end
end