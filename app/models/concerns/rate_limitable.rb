module RateLimitable
  extend ActiveSupport::Concern

  def rate_limit=(value)
    @rate_limit = value
  end

  def rate_limit?
    @rate_limit
  end

  def rate_limiter(by, options = {})
    return @rate_limiter if defined?(@rate_limiter)

    @rate_limiter = RateLimiter.new(by, options)
  end

  class_methods do
    def rate_limit(options = {})
      after_create do
        by = public_send(options[:by])

        if rate_limit? && by&.local?
          rate_limiter(by, options).record!
          @rate_limit_recorded = true
        end
      end

      after_rollback do
        rate_limiter(public_send(options[:by]), options).rollback! if @rate_limit_recorded
      end
    end
  end
end
