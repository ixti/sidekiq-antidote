# frozen_string_literal: true

require_relative "./shared"

module Sidekiq
  module Antidote
    module Middlewares
      class Client
        include Shared
        include Sidekiq::ClientMiddleware

        def initialize(tracker)
          @tracker = tracker
        end

        # @see https://github.com/sidekiq/sidekiq/wiki/Middleware
        # @see https://github.com/sidekiq/sidekiq/wiki/Job-Format
        def call(_, job_payload, queue_name, _)
          yield unless inhibit(job_payload, queue_name, @tracker)
        end
      end
    end
  end
end
