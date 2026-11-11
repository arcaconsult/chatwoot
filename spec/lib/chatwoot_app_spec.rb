require 'rails_helper'
require 'chatwoot_hub'

RSpec.describe ChatwootApp do
  # Arcaconsult: custom/ with enterprise/ left out (CW_EDITION=ce) must not name a namespace
  # that does not exist, or every prepend_mod_with crashes the boot.
  describe '.extensions' do
    before { allow(described_class).to receive(:custom?).and_return(true) }

    it 'lists enterprise before custom when enterprise/ is in place' do
      allow(described_class).to receive(:enterprise?).and_return(true)

      expect(described_class.extensions).to eq(%w[enterprise custom])
    end

    it 'lists only custom without enterprise/' do
      allow(described_class).to receive(:enterprise?).and_return(false)

      expect(described_class.extensions).to eq(%w[custom])
    end
  end

  describe '.self_hosted_paid?' do
    let!(:chatwoot_hub) { ChatwootHub }

    before do
      allow(described_class).to receive(:enterprise?).and_return(true)
      allow(described_class).to receive(:chatwoot_cloud?).and_return(false)
    end

    %w[premium enterprise].each do |plan|
      it "allows self-hosted #{plan}" do
        allow(chatwoot_hub).to receive(:pricing_plan).and_return(plan)

        expect(described_class.self_hosted_paid?).to be(true)
      end
    end

    ['community', '', nil, 'unexpected'].each do |plan|
      it "rejects #{plan.inspect}" do
        allow(chatwoot_hub).to receive(:pricing_plan).and_return(plan)

        expect(described_class.self_hosted_paid?).to be(false)
      end
    end

    it 'excludes Cloud' do
      allow(described_class).to receive(:chatwoot_cloud?).and_return(true)
      allow(chatwoot_hub).to receive(:pricing_plan).and_return('enterprise')

      expect(described_class.self_hosted_paid?).to be(false)
    end

    it 'requires enterprise code' do
      allow(described_class).to receive(:enterprise?).and_return(false)
      allow(chatwoot_hub).to receive(:pricing_plan).and_return('premium')

      expect(described_class.self_hosted_paid?).to be(false)
    end
  end
end
