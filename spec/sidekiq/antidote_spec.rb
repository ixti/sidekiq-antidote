# frozen_string_literal: true

require "sidekiq/processor"

RSpec.describe Sidekiq::Antidote do
  it "registers server and client middleware" do
    expect(Sidekiq.default_configuration.server_middleware.exists?(Sidekiq::Antidote::Middlewares::Server))
      .to be true

    expect(Sidekiq.default_configuration.client_middleware.exists?(Sidekiq::Antidote::Middlewares::Client))
      .to be true
  end

  it "registers startup handler" do
    allow(described_class).to receive(:startup)

    Sidekiq.default_configuration.default_capsule.fire_event(:startup)

    expect(described_class).to have_received(:startup)
  end

  it "registers shutdown handler" do
    allow(described_class).to receive(:shutdown)

    Sidekiq.default_configuration.default_capsule.fire_event(:shutdown)

    expect(described_class).to have_received(:shutdown)
  end

  it "registers the tracker" do
    allow(described_class.tracker).to receive(:flush)

    Sidekiq.default_configuration.default_capsule.fire_event(:beat)

    expect(described_class.tracker).to have_received(:flush)
  end

  describe ".add" do
    before { allow(SecureRandom).to receive(:hex).and_return("123") }

    it "adds inhibitor to redis" do
      expect { described_class.add(treatment: "kill", class_qualifier: "A") }.to(
        change { redis_hgetall }.to({
          "123" => Sidekiq.dump_json(%w[kill A])
        })
      )
    end

    it "returns added inhibitor" do
      expect(described_class.add(treatment: "kill", class_qualifier: "A"))
        .to eq(Sidekiq::Antidote::Inhibitor.new(id: "123", treatment: "kill", class_qualifier: "A"))
    end
  end

  describe ".delete" do
    let!(:inhibitor) { described_class.add(treatment: "kill", class_qualifier: "A") }

    it "removes inhibitor from redis" do
      expect { described_class.delete(inhibitor.id) }.to(
        change { redis_hgetall }.to(be_empty)
      )
    end
  end

  describe ".inhibitors" do
    subject { described_class.inhibitors }

    let!(:inhibitors) do
      [
        described_class.add(treatment: "kill", class_qualifier: "A"),
        described_class.add(treatment: "skip", class_qualifier: "B")
      ]
    end

    it { is_expected.to be_an(Array).and match_array(inhibitors) }
  end

  describe ".remedy_for" do
    subject { described_class.remedy_for(job_record) }

    let(:job_record) { Sidekiq::JobRecord.new(simple_job_message(klass: "AntidoteTestJob")) }
    let(:inhibitor)  { described_class.add(treatment: "skip", class_qualifier: "**TestJob") }

    before do
      described_class.configure { |c| c.refresh_rate = 0.1 }
      described_class.startup
      inhibitor # add inhibitor to the repository
      sleep 0.1 # and wait for remedy to refresh
    end

    it { is_expected.to eq(inhibitor) }

    context "when job record does not have matching inhibitors" do
      let(:inhibitor) { described_class.add(treatment: "skip", class_qualifier: "FakeJob") }

      it { is_expected.to be nil }
    end
  end

  describe ".configure" do
    it "yields config object" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class::Config)
    end

    it "allows re-entrance" do
      described_class.configure { |c| c.refresh_rate = 42.0 }

      expect { |b| described_class.configure(&b) }
        .to yield_with_args(have_attributes(refresh_rate: 42.0))
    end
  end

  describe ".startup" do
    after { described_class.shutdown }

    it "starts asynchronous refresher" do
      expect { described_class.startup }
        .to change { described_class.instance_variable_get(:@remedy).refresher_running? }.to(true)
    end
  end

  describe ".shutdown" do
    before { described_class.startup }

    it "stops asynchronous refresher" do
      expect { described_class.shutdown }
        .to change { described_class.instance_variable_get(:@remedy).refresher_running? }.to(false)
    end
  end
end
