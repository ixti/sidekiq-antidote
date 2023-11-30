# frozen_string_literal: true

RSpec.describe Sidekiq::Antidote::Repository do
  subject(:repository) { described_class.new(redis_key) }

  let(:redis_key) { Sidekiq::Antidote::Config.new.redis_key }

  it { is_expected.to be_an Enumerable }

  describe "#each" do
    subject { repository.each { |inhibitor| yielded_results << inhibitor } }

    let(:yielded_results) { [] }

    before do
      hset(redis_key, "123", Sidekiq.dump_json(%w[kill A]))
      hset(redis_key, "456", Sidekiq.dump_json(%w[skip B]))
      hset(redis_key, "999", "broken")
    end

    it "yields each valid inhibitor" do
      expect { subject }.to(
        change { yielded_results }.to(
          contain_exactly(
            Sidekiq::Antidote::Inhibitor.new(id: "123", treatment: "kill", class_qualifier: "A"),
            Sidekiq::Antidote::Inhibitor.new(id: "456", treatment: "skip", class_qualifier: "B")
          )
        )
      )
    end

    it "prunes broken records" do
      expect { subject }.to(
        change { hgetall(redis_key) }.to({
          "123" => Sidekiq.dump_json(%w[kill A]),
          "456" => Sidekiq.dump_json(%w[skip B])
        })
      )
    end

    it { is_expected.to be repository }

    context "without block given" do
      subject { repository.each }

      it { is_expected.to be_an Enumerator }

      it "returns each valid inhibitor" do
        expect(subject).to contain_exactly(
          Sidekiq::Antidote::Inhibitor.new(id: "123", treatment: "kill", class_qualifier: "A"),
          Sidekiq::Antidote::Inhibitor.new(id: "456", treatment: "skip", class_qualifier: "B")
        )
      end

      it "prunes broken records" do
        expect { subject.to_a }.to(
          change { hgetall(redis_key) }.to({
            "123" => Sidekiq.dump_json(%w[kill A]),
            "456" => Sidekiq.dump_json(%w[skip B])
          })
        )
      end
    end
  end

  describe "#add" do
    before do
      hset(redis_key, "123", Sidekiq.dump_json(%w[kill A]))
    end

    it "adds inhibitor to redis" do
      allow(SecureRandom).to receive(:hex).and_return("456")

      expect { repository.add(treatment: "skip", class_qualifier: "B") }.to(
        change { hgetall(redis_key) }.to({
          "123" => Sidekiq.dump_json(%w[kill A]),
          "456" => Sidekiq.dump_json(%w[skip B])
        })
      )
    end

    it "returns added inhibitor" do
      allow(SecureRandom).to receive(:hex).and_return("456")

      expect(repository.add(treatment: "skip", class_qualifier: "B"))
        .to eq(Sidekiq::Antidote::Inhibitor.new(id: "456", treatment: "skip", class_qualifier: "B"))
    end

    context "when generated ID already exists" do
      before { allow(SecureRandom).to receive(:hex).and_return("123", "456") }

      it "retries ID generation" do
        expect { repository.add(treatment: "skip", class_qualifier: "B") }.to(
          change { hgetall(redis_key) }.to({
            "123" => Sidekiq.dump_json(%w[kill A]),
            "456" => Sidekiq.dump_json(%w[skip B])
          })
        )
      end

      it "returns added inhibitor" do
        expect(repository.add(treatment: "skip", class_qualifier: "B"))
          .to eq(Sidekiq::Antidote::Inhibitor.new(id: "456", treatment: "skip", class_qualifier: "B"))
      end
    end

    context "when can't find available ID" do
      before { allow(SecureRandom).to receive(:hex).and_return("123") }

      it "fails" do
        expect { repository.add(treatment: "skip", class_qualifier: "B") }
          .to raise_error(%r{can't generate available ID})
      end
    end
  end

  describe "#delete" do
    subject { repository.delete("456") }

    before do
      hset(redis_key, "123", Sidekiq.dump_json(%w[kill A]))
      hset(redis_key, "456", Sidekiq.dump_json(%w[skip B]))
      hset(redis_key, "789", Sidekiq.dump_json(%w[skip C]))
    end

    it { is_expected.to be nil }

    it "removes matching inhibitor" do
      expect { subject }.to(
        change { hgetall(redis_key) }.to({
          "123" => Sidekiq.dump_json(%w[kill A]),
          "789" => Sidekiq.dump_json(%w[skip C])
        })
      )
    end

    context "when ID not found" do
      subject { repository.delete("deadbeef") }

      it { is_expected.to be nil }

      it "does nothing" do
        expect { subject }.to(keep_unchanged { hgetall(redis_key) })
      end
    end

    context "with multiple IDs" do
      subject { repository.delete("456", "deadbeef", "789") }

      it { is_expected.to be nil }

      it "removes matching inhibitor" do
        expect { subject }.to(
          change { hgetall(redis_key) }.to({
            "123" => Sidekiq.dump_json(%w[kill A])
          })
        )
      end
    end
  end
end
