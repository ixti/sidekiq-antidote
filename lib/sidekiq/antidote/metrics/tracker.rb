# frozen_string_literal: true

module Sidekiq
  module Antidote
    module Metrics
      class Tracker
        def initialize
          @inhibitions = Hash.new(0)
          @lock = Mutex.new
        end

        def track(inhibitor_name, job_class)
          @lock.synchronize do
            @inhibitions["#{job_class}|#{inhibitor_name}"] += 1
          end
        end

        def flush(time = Time.now)
          inhibitions = reset
          stats = "i|#{time.utc.strftime('%Y%m%d|%-H:%-M')}"

          Sidekiq.redis do |conn|
            conn.pipelined do |xa|
              inhibitions.each_pair do |key, value|
                xa.hincrby stats, key, value
              end
              xa.expire(stats, 8 * 60 * 60)
            end
          end
        end

        private

        def reset
          @lock.synchronize do
            inhibitions = @inhibitions
            @inhibitions = Hash.new(0)

            inhibitions
          end
        end
      end
    end
  end
end
