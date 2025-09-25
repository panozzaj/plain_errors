require 'spec_helper'

RSpec.describe PlainErrors do
  describe '.configuration' do
    it 'returns a configuration instance' do
      expect(described_class.configuration).to be_a(PlainErrors::Configuration)
    end

    it 'returns the same instance on multiple calls' do
      config1 = described_class.configuration
      config2 = described_class.configuration
      expect(config1).to be(config2)
    end
  end

  describe '.configure' do
    it 'yields the configuration' do
      described_class.configure do |config|
        expect(config).to be_a(PlainErrors::Configuration)
      end
    end

    it 'allows setting configuration options' do
      described_class.configure do |config|
        config.enabled = false
        config.show_code_snippets = false
      end

      expect(described_class.configuration.enabled).to be false
      expect(described_class.configuration.show_code_snippets).to be false
    end
  end
end