# frozen_string_literal: true

if ENV['DISABLE_SIMPLECOV'] != 'true'
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter 'lib/linter'
    add_group 'Policies', 'app/policies'
    add_group 'Presenters', 'app/presenters'
    add_group 'Serializers', 'app/serializers'
    add_group 'Services', 'app/services'
    add_group 'Validators', 'app/validators'
  end
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = 'tmp/rspec/examples.txt'
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true

    config.around(:example, :without_verify_partial_doubles) do |example|
      mocks.verify_partial_doubles = false
      example.call
      mocks.verify_partial_doubles = true
    end
  end

  config.before :suite do
    Rails.application.load_seed
    Chewy.strategy(:bypass)
  end

  config.after :suite do
    FileUtils.rm_rf(Dir[Rails.root.join('spec', 'test_files')])
  end
end

def body_as_json
  json_str_to_hash(response.body)
end

def json_str_to_hash(str)
  JSON.parse(str, symbolize_names: true)
end

def expect_push_bulk_to_match(klass, matcher)
  expect(Sidekiq::Client).to receive(:push_bulk).with(hash_including({
    'class' => klass,
    'args' => matcher,
  }))
end

class StreamingServerManager
  @running_thread = nil
  def initialize
    at_exit { stop }
  end

  def start
    return if @running_thread

    queue = Queue.new

    @queue = queue

    @running_thread = Thread.new do
      Open3.popen2e(
        {
          'REDIS_NAMESPACE' => 'mastodon_test',
          'DB_NAME' => 'mastodon_test',
          'RAILS_ENV' => 'test',
          'NODE_ENV' => 'test',
        },
        'yarn start',
        chdir: Rails.root.join('streaming')
      ) do |_stdin, stdout_err, process_thread|
        status = :starting

        # Spawn a thread to listen on streaming server output
        Thread.new do
          stdout_err.each_line do |line|
            puts "Streaming server: #{line}"

            if status == :starting && line.match('Streaming API now listening on')
              status = :started
              @queue.enq 'started'
            end
          end
        end

        # And another thread to listen on commands from the main thread
        loop do
          msg = queue.pop

          case msg
          when 'stop'
            # we need to properly stop the reading thread
            # output_thread.kill

            Process.kill('KILL', process_thread.pid)

            @running_thread.kill
          end
        end
      end
    end

    # wait for 10 seconds for the streaming server to start
    Timeout.timeout(10) do
      loop do
        break if @queue.pop == 'started'
      end
    end
  end

  def stop
    return unless @running_thread

    @queue.enq 'stop'

    # Wait for the thread to end
    @running_thread.join
  end
end
