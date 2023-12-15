# frozen_string_literal: true

require_relative "./shared"

module Sidekiq
  module Antidote
    module Middlewares
      class Client
        include Shared
        include Sidekiq::ClientMiddleware

        # @see https://github.com/sidekiq/sidekiq/wiki/Middleware
        # @see https://github.com/sidekiq/sidekiq/wiki/Job-Format
        def call(_, job_payload, queue_name, _)
          yield unless inhibit(job_payload, queue_name)
        end
      end
    end
  end
end
