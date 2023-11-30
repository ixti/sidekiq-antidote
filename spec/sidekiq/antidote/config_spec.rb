# frozen_string_literal: true

RSpec.describe Sidekiq::Antidote::Config do
  subject(:config) { described_class.new }

  describe "#redis_key" do
    subject { config.redis_key }

    context "when key prefix was not set" do
      it { is_expected.to eq "sidekiq-antidote" }
    end

    context "when key prefix was provided" do
      before { config.key_prefix = "my-app:" }

      it { is_expected.to eq "my-app:sidekiq-antidote" }
    end
  end

  describe "#key_prefix=" do
    it "sets prefix of the redis key" do
      expect { config.key_prefix = "my-app:" }
        .to change(config, :redis_key).to "my-app:sidekiq-antidote"
    end

    it "allows clear out previously set key prefix" do
      config.key_prefix = "my-app:"

      expect { config.key_prefix = nil }
        .to change(config, :redis_key).to "sidekiq-antidote"
    end

    it "fails if given value is neither ‹nil›, nor ‹String›" do
      expect { config.key_prefix = :nope }
        .to raise_error(ArgumentError, %r{expected String, or nil})
    end
  end

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
