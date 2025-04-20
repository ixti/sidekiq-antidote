# frozen_string_literal: true

require "sidekiq"
require "sidekiq/api"

require_relative "./antidote/config"
require_relative "./antidote/inhibitor"
require_relative "./antidote/middlewares/client"
require_relative "./antidote/middlewares/server"
require_relative "./antidote/remedy"
require_relative "./antidote/repository"
require_relative "./antidote/version"
require_relative "./antidote/metrics/tracker"

module Sidekiq
  module Antidote
    MUTEX = Mutex.new
    private_constant :MUTEX

    @config     = Config.new.freeze
    @repository = Repository.new
    @remedy     = Remedy.new(@config.refresh_rate, repository: @repository)

    class << self
      extend Forwardable

      # @!method add(treatment:, class_qualifier:)
      #   @param (see Repository#add)
      #   @return (see Repository#add)
      def_delegators :@repository, :add

      # @!method delete(*ids)
      #   @param (see Repository#delete)
      #   @return (see Repository#delete)
      def_delegators :@repository, :delete

      # @return [Array<Inhibitor>] Live list of inhibitors
      def inhibitors
        @repository.to_a
      end

      # @api internal
      # @param job_record [Sidekiq::JobRecord]
      # @return [Inhibitor, nil]
      def remedy_for(job_record)
        @remedy.find { _1.match?(job_record) }
      end

      # Yields `config` for a block.
      #
      # @example
      #   Sidekiq::Antidote.configure do |config|
      #     config.refresh_rate = 42.0
      #   end
      #
      # @yieldparam config [Config]
      def configure
        MUTEX.synchronize do
          config = @config.dup

          yield config

          @config = config.freeze

          self
        ensure
          reinit_remedy
        end
      end

      # Starts inhibitors poller.
      #
      # @return [self]
      def startup
        MUTEX.synchronize { reinit_remedy.start_refresher }

        self
      end

      # Shutdown inhibitors poller.
      #
      # @return [self]
      def shutdown
        MUTEX.synchronize { @remedy.stop_refresher }

        self
      end

      # @api internal
      #
      # @return [nil]
      def log(severity)
        Sidekiq.logger.public_send(severity) { "sidekiq-antidote: #{yield}" }
        nil
      end

      def tracker
        @tracker ||= Sidekiq::Antidote::Metrics::Tracker.new
      end

      private

      def reinit_remedy
        @remedy.stop_refresher
        @remedy = Remedy.new(@config.refresh_rate, repository: @repository)
      end
    end
  end

  # TODO: How to test both configure_{client,server}?
  configure_client do |config|
    config.client_middleware do |chain|
      chain.add Sidekiq::Antidote::Middlewares::Client, Antidote.tracker
    end
  end

  configure_server do |config|
    config.on(:startup)  { Antidote.startup }
    config.on(:shutdown) { Antidote.shutdown }
    config.on(:beat) { Antidote.tracker.flush }

    config.client_middleware do |chain|
      chain.add Sidekiq::Antidote::Middlewares::Client, Antidote.tracker
    end

    config.server_middleware do |chain|
      chain.add Sidekiq::Antidote::Middlewares::Server, Antidote.tracker
    end
  end
end
