SPEC_ROOT = File.expand_path(__dir__)

$LOAD_PATH << SPEC_ROOT

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run :focus
  config.run_all_when_everything_filtered = true
  config.disable_monkey_patching!
  # config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.profile_examples = 3

  config.order = :random

  Kernel.srand config.seed #this allows you to use `--seed` to deterministically reproduce failures
end

def vcenter_config_hash
  {
    vcenter_ip: ENV['VCENTER_IP'],
    username: ENV['USERNAME'],
    password: ENV['PASSWORD'],
    datacenter_name: ENV['DATACENTER_NAME'],
    datastore_name: ENV['DATASTORE_NAME'],
  }
end
