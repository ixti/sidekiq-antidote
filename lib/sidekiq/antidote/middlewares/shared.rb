# frozen_string_literal: true

require "sidekiq/api"

module Sidekiq
  module Antidote
    module Middlewares
      module Shared
        private

        # @return [true] if message was inhibited
        # @return [false] otherwise
        def inhibit(message)
          job_record = Sidekiq::JobRecord.new(message)
          inhibitor  = Antidote.remedy_for(job_record)
          return false unless inhibitor

          Antidote.log(:warn) { "I've got a poison! -- #{job_record.display_class}" }
          Antidote.log(:warn) { "I've got a remedy! -- #{inhibitor}" }
          DeadSet.new.kill(Sidekiq.dump_json(message)) if inhibitor.lethal?

          true
        end
      end
    end
  end
end
