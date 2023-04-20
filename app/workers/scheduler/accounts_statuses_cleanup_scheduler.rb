# frozen_string_literal: true

class Scheduler::AccountsStatusesCleanupScheduler
  include Sidekiq::Worker
  include Redisable

  # This limit is mostly to be nice to the fediverse at large and not
  # generate too much traffic.
  # This also helps limiting the running time of the scheduler itself.
  MAX_BUDGET         = 150

  # This is an attempt to spread the load across instances, as various
  # accounts are likely to have various followers.
  PER_ACCOUNT_BUDGET = 5

  # This is an attempt to limit the workload generated by status removal
  # jobs to something the particular instance can handle.
  PER_THREAD_BUDGET  = 6

  # Those avoid loading an instance that is already under load
  MAX_DEFAULT_SIZE    = 200
  MAX_DEFAULT_LATENCY = 5
  MAX_PUSH_SIZE       = 500
  MAX_PUSH_LATENCY    = 10

  # 'pull' queue has lower priority jobs, and it's unlikely that pushing
  # deletes would cause much issues with this queue if it didn't cause issues
  # with default and push. Yet, do not enqueue deletes if the instance is
  # lagging behind too much.
  MAX_PULL_SIZE       = 10_000
  MAX_PULL_LATENCY    = 5.minutes.to_i

  sidekiq_options retry: 0, lock: :until_executed, lock_ttl: 1.day.to_i

  def perform
    return if under_load?

    budget = compute_budget
    first_policy_id = last_processed_id

    loop do
      num_processed_accounts = 0

      scope = AccountStatusesCleanupPolicy.where(enabled: true)
      scope = scope.where(id: first_policy_id...) if first_policy_id.present?
      scope.find_each(order: :asc) do |policy|
        num_deleted = AccountStatusesCleanupService.new.call(policy, [budget, PER_ACCOUNT_BUDGET].min)
        num_processed_accounts += 1 unless num_deleted.zero?
        budget -= num_deleted
        if budget.zero?
          save_last_processed_id(policy.id)
          break
        end
      end

      # The idea here is to loop through all policies at least once until the budget is exhausted
      # and start back after the last processed account otherwise
      break if budget.zero? || (num_processed_accounts.zero? && first_policy_id.nil?)

      first_policy_id = nil
    end
  end

  def compute_budget
    threads = Sidekiq::ProcessSet.new.select { |x| x['queues'].include?('push') }.pluck('concurrency').sum
    [PER_THREAD_BUDGET * threads, MAX_BUDGET].min
  end

  def under_load?
    queue_under_load?('default', MAX_DEFAULT_SIZE, MAX_DEFAULT_LATENCY) || queue_under_load?('push', MAX_PUSH_SIZE, MAX_PUSH_LATENCY) || queue_under_load?('pull', MAX_PULL_SIZE, MAX_PULL_LATENCY)
  end

  private

  def queue_under_load?(name, max_size, max_latency)
    queue = Sidekiq::Queue.new(name)
    queue.size > max_size || queue.latency > max_latency
  end

  def last_processed_id
    redis.get('account_statuses_cleanup_scheduler:last_policy_id')
  end

  def save_last_processed_id(id)
    if id.nil?
      redis.del('account_statuses_cleanup_scheduler:last_policy_id')
    else
      redis.set('account_statuses_cleanup_scheduler:last_policy_id', id, ex: 1.hour.seconds)
    end
  end
end
