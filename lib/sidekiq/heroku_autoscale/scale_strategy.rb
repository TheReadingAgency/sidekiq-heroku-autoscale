module Sidekiq
  module HerokuAutoscale

    class ScaleStrategy
      attr_accessor :mode, :max_dynos, :workers_per_dyno, :min_factor

      def initialize(mode: :binary, max_dynos: 1, workers_per_dyno: 25, min_factor: 0)
        @mode = mode
        @max_dynos = max_dynos
        @workers_per_dyno = workers_per_dyno
        @min_factor = min_factor
      end

      # @param [QueueSystem] system interface to the queuing system
      # @return [Integer] target number of workers
      def call(sys)
        case @mode.to_s
        when 'linear'
          linear(sys)
        else
          binary(sys)
        end
      end

      def binary(sys)
        sys.has_work? ? @max_dynos : 0
      end

      def linear(sys)
        total_capacity = (@max_dynos * @workers_per_dyno).to_f
        min_capacity = [0, @min_factor].max.to_f * @workers_per_dyno
        min_capacity_percentage = min_capacity / total_capacity
        requested_capacity_percentage = sys.total_work / total_capacity

        # Scale requested capacity taking into account the minimum required
        scale_factor = (requested_capacity_percentage - min_capacity_percentage) / (total_capacity - min_capacity_percentage)
        scale_factor = 0 if scale_factor.nan? # Handle DIVZERO
        scaled_capacity_percentage = scale_factor * total_capacity

        ideal_dynos = ([0, scaled_capacity_percentage].max * @max_dynos).ceil
        minimum_dynos = [sys.dynos, ideal_dynos].max  # Don't scale down past number of currently engaged workers
        maximum_dynos = [minimum_dynos, @max_dynos].min  # Don't scale up past number of max workers
        [minimum_dynos, maximum_dynos].min
      end
    end

  end
end