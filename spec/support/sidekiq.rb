# frozen_string_literal: true

require "securerandom"
require "sidekiq"
require "sidekiq/cli"

$TESTING = false # rubocop:disable Style/GlobalVars

class AntidoteTestJob
  include Sidekiq::Job

  def perform; end
end

module AntidoteTesting
  def simple_job_message(klass:)
    {
      "class"       => klass.to_s,
      "jid"         => SecureRandom.hex(12),
      "args"        => [],
      "created_at"  => Time.now.to_i,
      "enqueued_at" => Time.now.to_i
    }
  end

  def active_job_message(klass:)
    {
      "class"       => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
      "wrapped"     => klass.to_s,
      "jid"         => SecureRandom.hex(12),
      "args"        => [{ "job_class" => klass, "job_id" => SecureRandom.hex(12), "arguments" => [] }],
      "created_at"  => Time.now.to_i,
      "enqueued_at" => Time.now.to_i
    }
  end

  def redis_hgetall
    Sidekiq.redis { _1.call("HGETALL", "sidekiq-antidote") }
  end

  def redis_hset(field, value)
    Sidekiq.redis { _1.call("HSET", "sidekiq-antidote", field, value) }
  end
end

RSpec.configure do |config|
  config.include AntidoteTesting

  config.before do
    Sidekiq.redis { _1.call("FLUSHDB") }
  end
end
