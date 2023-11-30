# frozen_string_literal: true

RSpec.describe Sidekiq::Antidote::VERSION do
  it { is_expected.to be_a(String).and match(%r{\A\d+(\.\d+){2}}) }
end
