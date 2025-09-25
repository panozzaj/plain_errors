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

        expect(result[0]).to eq('  0: ./app/controllers/users_controller.rb:15:in `show\'')
        expect(result[1]).to eq('  1: ./app/models/user.rb:42:in `find_by_email\'')
        expect(result[2]).to eq('  2: /usr/local/ruby/gems/rack/lib/rack.rb:123:in `call\'')
        expect(result[3]).to eq('  3: ./config/application.rb:8:in `<top (required)>\'')
      end

      it 'abbreviates paths within application root' do
        formatter = described_class.new(backtrace)
        result = formatter.format

        expect(result[0]).to include('./app/controllers/')
        expect(result[1]).to include('./app/models/')
      end

      it 'does not abbreviate paths outside application root' do
        formatter = described_class.new(backtrace)
        result = formatter.format

        expect(result[2]).to include('/usr/local/ruby/gems/')
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

        expect(result[0]).to eq('  0: /app/controllers/users_controller.rb:15:in `show\'')
      end
    end
  end

  describe '#abbreviate_path' do
    let(:formatter) { described_class.new([]) }

    it 'abbreviates paths starting with application root' do
      trace_line = '/app/controllers/users_controller.rb:15:in `show\''
      result = formatter.send(:abbreviate_path, trace_line)

      expect(result).to eq('./controllers/users_controller.rb:15:in `show\'')
    end

    it 'leaves other paths unchanged' do
      trace_line = '/usr/local/ruby/lib/file.rb:15:in `method\''
      result = formatter.send(:abbreviate_path, trace_line)

      expect(result).to eq('/usr/local/ruby/lib/file.rb:15:in `method\'')
    end
  end
end