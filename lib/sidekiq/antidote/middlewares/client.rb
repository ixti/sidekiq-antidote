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
        def call(_, job_payload, _, _)
          yield unless inhibit(job_payload)
        end
      end
    end
  end
end
