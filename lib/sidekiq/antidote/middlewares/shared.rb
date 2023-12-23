# frozen_string_literal: true

require "sidekiq/api"

module Sidekiq
  module Antidote
    module Middlewares
      module Shared
        private

        # @return [true] if message was inhibited
        # @return [false] otherwise
        def inhibit(message, queue_name, tracker)
          job_record = Sidekiq::JobRecord.new(message)
          inhibitor  = Antidote.remedy_for(job_record)
          return false unless inhibitor

          Antidote.log(:warn) { "I've got a poison! -- #{job_record.display_class}" }
          Antidote.log(:warn) { "I've got a remedy! -- #{inhibitor}" }

          tracker.track(inhibitor.treatment, job_record.class)
          apply_treatment(inhibitor, job_record, queue_name)

          true
        end

        def apply_treatment(inhibitor, job_record, queue_name)
          # Ensure message has queue name
          message = Sidekiq.dump_json(job_record.item.merge({ "queue" => queue_name }))

          case inhibitor.treatment
          when "kill" then DeadSet.new.kill(message)
          end
        end
      end
    end
  end
end
