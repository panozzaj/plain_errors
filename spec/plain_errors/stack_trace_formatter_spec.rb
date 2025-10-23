require 'spec_helper'

RSpec.describe PlainErrors::StackTraceFormatter do
  before do
    PlainErrors.configure do |config|
      config.application_root = '/app'
    end
  end

  describe '#format' do
    context 'with valid backtrace' do
      let(:backtrace) do
        [
          '/app/app/controllers/users_controller.rb:15:in `show\'',
          '/app/app/models/user.rb:42:in `find_by_email\'',
          '/usr/local/ruby/gems/rack/lib/rack.rb:123:in `call\'',
          '/app/config/application.rb:8:in `<top (required)>\'',
        ]
      end

      it 'formats each line with index' do
        formatter = described_class.new(backtrace)
        result = formatter.format

        expect(result[0]).to match(/0: .*app\/controllers\/users_controller.rb:15:in `show'/)
        expect(result[1]).to match(/1: .*app\/models\/user.rb:42:in `find_by_email'/)
        expect(result[2]).to match(/2: .*gems\/rack\/lib\/rack.rb:123:in `call'/)
        expect(result[3]).to match(/3: .*config\/application.rb:8:in `<top \(required\)>'/)
      end

      it 'returns formatted output' do
        formatter = described_class.new(backtrace)
        result = formatter.format

        expect(result.length).to eq(4)
        expect(result).to all(match(/^\d+: /))
      end
    end

    context 'with empty backtrace' do
      it 'returns no stack trace message' do
        formatter = described_class.new([])
        result = formatter.format

        expect(result).to eq(['No stack trace available'])
      end
    end

    context 'with nil backtrace' do
      it 'returns no stack trace message' do
        formatter = described_class.new(nil)
        result = formatter.format

        expect(result).to eq(['No stack trace available'])
      end
    end

    context 'without application root configured' do
      before do
        PlainErrors.configure do |config|
          config.application_root = nil
        end
      end

      let(:backtrace) { ['/app/controllers/users_controller.rb:15:in `show\''] }

      it 'does not abbreviate any paths' do
        formatter = described_class.new(backtrace)
        result = formatter.format

        expect(result[0]).to eq('0: /app/controllers/users_controller.rb:15:in `show\'')
      end
    end

    context 'with max_stack_trace_lines configured' do
      let(:long_backtrace) do
        (0..9).map { |i| "/app/file#{i}.rb:#{i}:in `method#{i}'" }
      end

      context 'when max_stack_trace_lines is set to 5' do
        before do
          PlainErrors.configure do |config|
            config.max_stack_trace_lines = 5
          end
        end

        it 'truncates the stack trace to 5 lines' do
          formatter = described_class.new(long_backtrace)
          result = formatter.format

          # Should have 5 lines + "(N more lines omitted)" message
          expect(result.length).to eq(6)
          expect(result[0]).to match(/0: .*file0.rb:0:in `method0'/)
          expect(result[4]).to match(/4: .*file4.rb:4:in `method4'/)
          expect(result[5]).to eq('(5 more lines omitted)')
        end
      end

      context 'when max_stack_trace_lines is nil' do
        before do
          PlainErrors.configure do |config|
            config.max_stack_trace_lines = nil
          end
        end

        it 'does not truncate the stack trace' do
          formatter = described_class.new(long_backtrace)
          result = formatter.format

          # Should have all 10 lines
          expect(result.length).to eq(10)
          expect(result[0]).to match(/0: .*file0.rb:0:in `method0'/)
          expect(result[9]).to match(/9: .*file9.rb:9:in `method9'/)
        end
      end

      context 'when backtrace is shorter than max_stack_trace_lines' do
        before do
          PlainErrors.configure do |config|
            config.max_stack_trace_lines = 10
          end
        end

        let(:short_backtrace) { ['/app/file.rb:1:in `method\''] }

        it 'does not add truncation message' do
          formatter = described_class.new(short_backtrace)
          result = formatter.format

          expect(result.length).to eq(1)
          expect(result[0]).to match(/0: .*file.rb:1:in `method'/)
        end
      end
    end
  end

end