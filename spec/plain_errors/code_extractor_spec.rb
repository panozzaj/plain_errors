require 'spec_helper'
require 'tempfile'

RSpec.describe PlainErrors::CodeExtractor do
  let(:sample_code) do
    <<~RUBY
      def sample_method
        x = 1
        y = 2
        z = x + y
        puts z
        raise "Error at line 6"
        puts "This won't run"
      end
    RUBY
  end

  let(:temp_file) do
    file = Tempfile.new(['sample', '.rb'])
    file.write(sample_code)
    file.close
    file
  end

  after { temp_file.unlink }

  describe '#extract' do
    context 'with valid file and line number' do
      it 'extracts code with default context' do
        extractor = described_class.new(temp_file.path, 6)
        result = extractor.extract(2)

        expect(result).to include('6:   raise "Error at line 6"')
        expect(result).to include('4:   z = x + y')
        expect(result).to include('8: end')
        expect(result.length).to eq 5
      end

      it 'handles context at beginning of file' do
        extractor = described_class.new(temp_file.path, 1)
        result = extractor.extract(3)

        expect(result).to include('1: def sample_method')
        expect(result.first).to start_with('1:')
        # Should strip blank lines from beginning, so result might be shorter
        expect(result.length).to be >= 1
      end

      it 'handles context at end of file' do
        extractor = described_class.new(temp_file.path, 8)
        result = extractor.extract(3)

        expect(result).to include('8: end')
        expect(result.last).to match(/\d+:/)
        # Should strip blank lines from end, so result might be shorter
        expect(result.length).to be >= 1
      end

      it 'formats line numbers without indentation or markers' do
        extractor = described_class.new(temp_file.path, 6)
        result = extractor.extract(2)

        result.each do |line|
          expect(line).to match(/^\d+:/)
        end
      end
    end

    context 'with non-existent file' do
      it 'returns error message' do
        extractor = described_class.new('/non/existent/file.rb', 1)
        result = extractor.extract

        expect(result).to eq(["Source file not found: /non/existent/file.rb"])
      end
    end

    context 'with file read error' do
      it 'returns error message when file cannot be read' do
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:readlines).and_raise(Errno::EACCES, 'Permission denied')

        extractor = described_class.new(temp_file.path, 1)
        result = extractor.extract

        expect(result.first).to start_with('Error reading source file:')
      end
    end

    context 'with different context sizes' do
      it 'respects custom context size' do
        extractor = described_class.new(temp_file.path, 4)

        result_small = extractor.extract(1)
        result_large = extractor.extract(3)

        expect(result_small.length).to be < result_large.length
        expect(result_small.length).to eq 3
        expect(result_large.length).to eq 7
      end
    end
  end
end