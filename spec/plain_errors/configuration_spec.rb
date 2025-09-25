require 'spec_helper'

RSpec.describe PlainErrors::Configuration do
  subject { described_class.new }

  describe '#initialize' do
    it 'sets default values' do
      expect(subject.enabled).to be true
      expect(subject.show_code_snippets).to be true
      expect(subject.code_lines_context).to eq 3
      expect(subject.show_request_info).to be false
      expect(subject.show_variables).to be false
      expect(subject.max_variable_size).to eq 1000
      expect(subject.application_root).to be_nil
      expect(subject.trigger_headers).to eq ['X-Plain-Errors', 'X-LLM-Request']
    end
  end

  describe 'attribute accessors' do
    it 'allows setting and getting enabled' do
      subject.enabled = false
      expect(subject.enabled).to be false
    end

    it 'allows setting and getting show_code_snippets' do
      subject.show_code_snippets = false
      expect(subject.show_code_snippets).to be false
    end

    it 'allows setting and getting code_lines_context' do
      subject.code_lines_context = 5
      expect(subject.code_lines_context).to eq 5
    end

    it 'allows setting and getting show_request_info' do
      subject.show_request_info = true
      expect(subject.show_request_info).to be true
    end

    it 'allows setting and getting show_variables' do
      subject.show_variables = true
      expect(subject.show_variables).to be true
    end

    it 'allows setting and getting max_variable_size' do
      subject.max_variable_size = 500
      expect(subject.max_variable_size).to eq 500
    end

    it 'allows setting and getting application_root' do
      subject.application_root = '/app'
      expect(subject.application_root).to eq '/app'
    end

    it 'allows setting and getting trigger_headers' do
      subject.trigger_headers = ['X-Custom-Error']
      expect(subject.trigger_headers).to eq ['X-Custom-Error']
    end
  end
end