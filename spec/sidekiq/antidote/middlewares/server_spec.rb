# frozen_string_literal: true

RSpec.describe Sidekiq::Antidote::Middlewares::Server do
  subject(:middleware) { described_class.new tracker }

  let(:tracker) { Sidekiq::Antidote::Metrics::Tracker.new }

  before do
    allow(tracker).to receive(:track).and_call_original
  end

  describe "#call" do
    let(:job_instance) { AntidoteTestJob.new }
    let(:job_message)  { simple_job_message(klass: job_instance.class.name) }

    it "passes execution downstream" do
      expect { |b| middleware.call(job_instance, job_message, Sidekiq.redis_pool, &b) }
        .to yield_control
    end

    context "when job matches <skip> inhibitor" do
      before do
        Sidekiq::Antidote.add(treatment: "skip", class_qualifier: "**TestJob")
        Sidekiq::Antidote.configure { |c| c.refresh_rate = 0.1 }
        Sidekiq::Antidote.startup
        sleep 0.1
      end

      it "terminates chain execution" do
        expect { |b| middleware.call(job_instance, job_message, Sidekiq.redis_pool, &b) }
          .not_to yield_control
      end

      it "does not deliver job to morgue" do
        expect { |b| middleware.call(job_instance, job_message, Sidekiq.redis_pool, &b) }
          .to keep_unchanged(Sidekiq::DeadSet.new, :size)
      end

      it "tracks the inhibition" do
        middleware.call(job_instance, job_message, Sidekiq.redis_pool)

        expect(tracker).to have_received(:track).with(
          "skip",
          "AntidoteTestJob"
        )
      end
    end

    context "when job matches <kill> inhibitor" do
      before do
        Sidekiq::Antidote.add(treatment: "kill", class_qualifier: "**TestJob")
        Sidekiq::Antidote.configure { |c| c.refresh_rate = 0.1 }
        Sidekiq::Antidote.startup
        sleep 0.1
      end

      it "terminates chain execution" do
        expect { |b| middleware.call(job_instance, job_message, Sidekiq.redis_pool, &b) }
          .not_to yield_control
      end

      it "delivers job to morgue" do
        expect { |b| middleware.call(job_instance, job_message, Sidekiq.redis_pool, &b) }
          .to change(Sidekiq::DeadSet.new, :size)
      end

      it "tracks the inhibition" do
        middleware.call(job_instance, job_message, Sidekiq.redis_pool)

        expect(tracker).to have_received(:track).with(
          "kill",
          "AntidoteTestJob"
        )
      end
    end
  end
end
