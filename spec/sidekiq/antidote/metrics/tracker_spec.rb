# frozen_string_literal: true

RSpec.describe Sidekiq::Antidote::Metrics::Tracker do
  subject(:tracker) { described_class.new }

  describe "#track" do
    let(:inhibitor_name) { "skip" }
    let(:job_class)      { "AntidoteTestJob" }

    it "adds metric to inhibitions" do
      expect { tracker.track(inhibitor_name, job_class) }
        .to change { tracker.instance_variable_get(:@inhibitions)["AntidoteTestJob|skip"] }.to 1
    end
  end

  describe "#flush" do
    before do
      4.times do
        tracker.track("skip", "AntidoteTestJob")
      end
    end

    it "stores cached metrics in redis" do
      key = "i|#{Time.now.utc.strftime('%Y%m%d|%-H:%-M')}"
      expect { tracker.flush }.to(change { redis_hgetall(key: key) })

      expect(redis_hgetall(key: key)["AntidoteTestJob|skip"]).to eq "4"
    end
  end
end
