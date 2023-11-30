# frozen_string_literal: true

module Sidekiq
  module Antidote
    class Config
      REDIS_KEY = "sidekiq-antidote"
      private_constant :REDIS_KEY

      # Default refresh rate
      REFRESH_RATE = 5.0

      # @return [String?]
      attr_reader :key_prefix

      # @return [Float]
      attr_reader :refresh_rate

      # Fully qualified Redis key
      #
      # @example Without key prefix (default)
      #   config.redis_key # => "sidekiq-antidote"
      #
      # @example With key prefix
      #   config.key_prefix = "foobar:"
      #   config.redis_key # => "foobar:sidekiq-antidote"
      #
      # @see #key_prefix
      # @return [String]
      attr_reader :redis_key

      def initialize
        @key_prefix   = nil
        @redis_key    = REDIS_KEY
        @refresh_rate = REFRESH_RATE
      end

      # Redis key prefix.
      #
      # @example
      #   config.key_prefix = "foobar:"
      #   config.redis_key # => "foobar:sidekiq-antidote"
      #
      # @see #redis_key
      # @param value [String, nil] String that should be prepended to redis key
      # @return [void]
      def key_prefix=(value)
        raise ArgumentError, "expected String, or nil; got #{value.class}" unless value.nil? || value.is_a?(String)

        @redis_key  = [value, REDIS_KEY].compact.join.freeze
        @key_prefix = value&.then(&:-@) # Don't freeze original String value if it was unfrozen
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
