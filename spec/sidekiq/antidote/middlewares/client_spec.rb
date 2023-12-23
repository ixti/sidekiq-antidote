# frozen_string_literal: true

RSpec.describe Sidekiq::Antidote::Middlewares::Client do
  subject(:middleware) { described_class.new Sidekiq::Antidote::Metrics::Tracker.new }

  describe "#call" do
    let(:job_class)   { AntidoteTestJob }
    let(:job_message) { simple_job_message(klass: "AntidoteTestJob") }

    it "passes execution downstream" do
      expect { |b| middleware.call(job_class, job_message, "default", Sidekiq.redis_pool, &b) }
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
        expect { |b| middleware.call(job_class, job_message, "default", Sidekiq.redis_pool, &b) }
          .not_to yield_control
      end

      it "does not deliver job to morgue" do
        expect { |b| middleware.call(job_class, job_message, "default", Sidekiq.redis_pool, &b) }
          .to keep_unchanged(Sidekiq::DeadSet.new, :size)
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
        expect { |b| middleware.call(job_class, job_message, "default", Sidekiq.redis_pool, &b) }
          .not_to yield_control
      end

      it "delivers job to morgue" do
        expect { |b| middleware.call(job_class, job_message, "default", Sidekiq.redis_pool, &b) }
          .to change(Sidekiq::DeadSet.new, :size)
      end
    end
  end
end
