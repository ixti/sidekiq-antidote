# frozen_string_literal: true

RSpec.describe Sidekiq::Antidote::SuspensionGroup do
  subject(:suspension_group) { described_class.new(name: name) }

  let(:name) { "group1" }

  it { is_expected.to be_an Enumerable }

  describe ".all" do
    subject { described_class.all }

    before do
      redis_lpush("sidekiq-antidote:suspend:group1", Sidekiq.dump_json(simple_job_message(klass: "A::B::CJob")))
      redis_lpush("sidekiq-antidote:suspend:group2", Sidekiq.dump_json(simple_job_message(klass: "A::B::CJob")))
      redis_lpush("sidekiq-antidote:suspend:group3", Sidekiq.dump_json(simple_job_message(klass: "A::B::CJob")))
    end

    it "returns all suspension groups" do
      expect(subject).to include(
        an_object_having_attributes(name: "group1"),
        an_object_having_attributes(name: "group2"),
        an_object_having_attributes(name: "group3")
      )

      expect(subject.first.size).to eq(1)
    end
  end

  describe "#each" do
    subject { suspension_group.each { |job_message| yielded_results << job_message } }

    let(:yielded_results) { [] }
    let(:job_message)     { simple_job_message(klass: "A::B::CJob") }

    before do
      redis_lpush("sidekiq-antidote:suspend:group1", Sidekiq.dump_json(job_message))
      redis_lpush("sidekiq-antidote:suspend:group1", Sidekiq.dump_json(job_message))
      redis_lpush("sidekiq-antidote:suspend:group1", Sidekiq.dump_json(job_message))
    end

    it "yields each valid inhibitor" do
      expect { subject }.to(
        change { yielded_results }.to(
          contain_exactly(
            Sidekiq.dump_json(job_message),
            Sidekiq.dump_json(job_message),
            Sidekiq.dump_json(job_message)
          )
        )
      )
    end
  end

  describe "#add" do
    let(:job_message) { simple_job_message(klass: "A::B::CJob") }

    before do
      redis_lpush("sidekiq-antidote:suspend:group1", Sidekiq.dump_json(job_message))
    end

    it "adds job message to redis" do
      expect { suspension_group.add(message: job_message) }.to(
        change { redis_llen("sidekiq-antidote:suspend:group1") }.from(1).to(2)
      )
    end
  end
end
