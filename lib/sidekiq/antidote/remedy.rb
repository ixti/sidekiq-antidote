# frozen_string_literal: true

require "concurrent"

module Sidekiq
  module Antidote
    # @api internal
    # Eventually consistent list of inhibitors. Used by middlewares to avoid
    # hitting Redis on every lookup.
    class Remedy
      include Enumerable

      # @param refresh_rate [Float]
      # @param repository [Repository]
      def initialize(refresh_rate, repository:)
        @refresher = Concurrent::TimerTask.new(execution_interval: refresh_rate, run_now: true) do
          repository.to_a.freeze
        end
      end

      # @overload each
      #   @return [Enumerator<Inhibitor>]
      #
      # @overload each(&block)
      #   For a block { |inhibitor| ... }
      #   @yieldparam inhibitor [Inhibitor]
      #   @return [self]
      def each(&block)
        return to_enum __method__ unless block

        start_refresher unless refresher_running?
        @refresher.value&.each(&block)

        self
      end

      # Starts inhibitors list async poller.
      #
      # @return [self]
      def start_refresher
        @refresher.execute
        self
      end

      # Stops inhibitors list async poller.
      #
      # @return [self]
      def stop_refresher
        @refresher.shutdown
        self
      end

      # Returns whenever inhibitors list async poller is running.
      #
      # @return [Boolean]
      def refresher_running?
        @refresher.running?
      end
    end
  end
end
