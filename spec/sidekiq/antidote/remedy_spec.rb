# frozen_string_literal: true

RSpec.describe Sidekiq::Antidote::Remedy do
  subject(:remedy) { described_class.new(refresh_rate, repository: repository) }

  let(:refresh_rate) { 0.1 }
  let(:repository)   { Sidekiq::Antidote::Repository.new("sidekiq-antidote") }

  after { remedy.stop_refresher }

  it { is_expected.to be_an Enumerable }

  it "polls repository regularily" do
    allow(repository).to receive(:to_a).and_call_original

    remedy.start_refresher
    sleep(4 * refresh_rate)

    expect(repository).to have_received(:to_a).at_least(4).times
    expect(repository).to have_received(:to_a).at_most(5).times
  end

  context "when repository poll fails" do
    before do
      attempt = 0

      allow(SecureRandom).to receive(:hex).and_return("123", "456", "789")
      allow(repository).to receive(:to_a).and_wrap_original do |m|
        attempt += 1

        if attempt <= 4
          raise "nope" if attempt.odd?

          repository.add(treatment: "skip", class_qualifier: "A#{attempt}")
        end

        m.call
      end

      remedy.start_refresher
      sleep(4 * refresh_rate)
    end

    it "keeps refresher runnning" do
      expect(remedy.refresher_running?).to be true
    end

    it "keeps updating the local cache" do
      expect(remedy.to_a).to contain_exactly(
        Sidekiq::Antidote::Inhibitor.new(id: "123", treatment: "skip", class_qualifier: "A2"),
        Sidekiq::Antidote::Inhibitor.new(id: "456", treatment: "skip", class_qualifier: "A4")
      )
    end
  end

  describe "#each" do
    subject { remedy.each { |inhibitor| yielded_results << inhibitor } }

    let(:yielded_results) { [] }

    before do
      allow(SecureRandom).to receive(:hex).and_return("123", "456", "789")

      repository.add(treatment: "kill", class_qualifier: "A")
      repository.add(treatment: "skip", class_qualifier: "B")
    end

    it { is_expected.to be remedy }

    it "yields each valid inhibitor" do
      remedy.start_refresher
      sleep refresh_rate

      expect { subject }.to(
        change { yielded_results }.to(
          contain_exactly(
            Sidekiq::Antidote::Inhibitor.new(id: "123", treatment: "kill", class_qualifier: "A"),
            Sidekiq::Antidote::Inhibitor.new(id: "456", treatment: "skip", class_qualifier: "B")
          )
        )
      )
    end

    context "without block given" do
      subject { remedy.each }

      it { is_expected.to be_an Enumerator }

      it "returns each valid inhibitor" do
        remedy.start_refresher
        sleep 0.1

        expect(subject).to contain_exactly(
          Sidekiq::Antidote::Inhibitor.new(id: "123", treatment: "kill", class_qualifier: "A"),
          Sidekiq::Antidote::Inhibitor.new(id: "456", treatment: "skip", class_qualifier: "B")
        )
      end
    end
  end

  describe "#start_refresher" do
    it "starts asynchronous refresher" do
      expect { remedy.start_refresher }.to change(remedy, :refresher_running?).to(true)
    end
  end

  describe "#stop_refresher" do
    before { remedy.start_refresher }

    it "stops asynchronous refresher" do
      expect { remedy.stop_refresher }.to change(remedy, :refresher_running?).to(false)
    end
  end

  describe "#refresher_running?" do
    subject { remedy.refresher_running? }

    it { is_expected.to be false }

    context "when refresher was stopped" do
      before { remedy.stop_refresher }

      it { is_expected.to be false }
    end

    context "when refresher was started" do
      before { remedy.start_refresher }

      it { is_expected.to be true }
    end
  end
end
