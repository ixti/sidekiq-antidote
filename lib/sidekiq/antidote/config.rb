# frozen_string_literal: true

module Sidekiq
  module Antidote
    class Config
      # Default refresh rate
      REFRESH_RATE = 5.0

      # @return [Float]
      attr_reader :refresh_rate

      def initialize
        @refresh_rate = REFRESH_RATE
      end

      # Inhibitors cache refresh rate in seconds.
      #
      # @param value [Float] refresh interval in seconds
      # @return [void]
      def refresh_rate=(value)
        unless value.is_a?(Float) && value.positive?
          raise ArgumentError, "expected positive Float; got #{value.inspect}"
        end

        @refresh_rate = value
      end
    end
  end
end
