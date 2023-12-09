# frozen_string_literal: true

RSpec.describe Sidekiq::Antidote::Config do
  subject(:config) { described_class.new }

  describe "#refresh_rate" do
    subject { config.refresh_rate }

    context "with default value" do
      it { is_expected.to eq 5.0 }
    end

    context "when refresh rate was overridden" do
      before { config.refresh_rate = 42.0 }

      it { is_expected.to eq 42.0 }
    end
  end

  describe "#refresh_rate=" do
    it "allows override refresh rate" do
      expect { config.refresh_rate = 42.0 }
        .to change(config, :refresh_rate).to 42.0
    end

    where(value: [42, "42", 0.0])
    with_them do
      it "fails" do
        expect { config.refresh_rate = value }
          .to raise_error(ArgumentError, %r{expected positive Float})
      end
    end
  end
end
